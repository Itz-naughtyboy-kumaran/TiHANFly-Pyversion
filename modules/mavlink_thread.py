import math
import time
from PyQt5.QtCore import pyqtSignal, QThread
from pymavlink import mavutil
from pymavlink.dialects.v20 import ardupilotmega as mavlink_dialect
from pymavlink.dialects.v20 import common as mavlink_common
from pymavlink.dialects.v20 import ardupilotmega as mavutil_ardupilot

class MAVLinkThread(QThread):
    telemetryUpdated = pyqtSignal(dict)
    statusTextChanged = pyqtSignal(str)
    current_msg = pyqtSignal(object)
    
    def __init__(self, drone, drone_commander=None):
        super().__init__()
        self.drone = drone
        self.drone_commander = drone_commander
        self.running = True
        self.current_telemetry_components = {
            'mode': "UNKNOWN", 'armed': False,
            'lat': None, 'lon': None, 'alt': None, 'rel_alt': None,
            'roll': None, 'pitch': None, 'yaw': None,
            'heading': None,
            'groundspeed': 0.0, 'airspeed': 0.0,
            # Battery fields
            'battery_remaining': None,  # Percentage (0-100)
            'voltage_battery': None,    # Volts
            'current_battery': None     # Amperes
        }
        
        # Debug: Check if drone_commander was passed
        if self.drone_commander is not None:
            print("[MAVLinkThread] ✅ Initialized with DroneCommander support")
        else:
            print("[MAVLinkThread] ⚠️ Initialized WITHOUT DroneCommander (parameters won't work)")
        
        print("[MAVLinkThread] Initialized (Event-driven).")

    def run(self):
        print("[MAVLinkThread] Thread started. Continuously listening for MAVLink messages...")
        
        # Counters for debugging
        param_msg_count = 0
        start_time = time.time()
        last_param_log_time = time.time()
        
        while self.running:
            try:
                msg = self.drone.recv_match(blocking=False, timeout=1)
                
                if msg:
                    self.current_msg.emit(msg)
                    msg_type = msg.get_type()
                    msg_dict = msg.to_dict()
                    telemetry_component_changed = False

                    # ========== HEARTBEAT - Armed Status & Flight Mode ==========
                    if msg_type == "HEARTBEAT":
                        mode_map = self.drone.mode_mapping()
                        inv_mode_map = {v: k for k, v in mode_map.items()}
                        new_mode = inv_mode_map.get(msg_dict['custom_mode'], "UNKNOWN")
                        new_armed_status = bool(
                            msg_dict['base_mode'] & mavutil.mavlink.MAV_MODE_FLAG_SAFETY_ARMED
                        )
                        
                        # Update mode if changed
                        if self.current_telemetry_components['mode'] != new_mode:
                            print(f"[MAVLinkThread] 🔄 MODE CHANGED: {self.current_telemetry_components['mode']} → {new_mode}")
                            self.current_telemetry_components['mode'] = new_mode
                            telemetry_component_changed = True
                        
                        # Update armed status if changed
                        if self.current_telemetry_components['armed'] != new_armed_status:
                            print(f"[MAVLinkThread] 🔄 ARMED STATUS CHANGED: {self.current_telemetry_components['armed']} → {new_armed_status}")
                            self.current_telemetry_components['armed'] = new_armed_status
                            telemetry_component_changed = True

                    # ========== COMMAND_ACK - Command Acknowledgments ==========
                    elif msg_type == "COMMAND_ACK":
                        # Log ARM/DISARM acknowledgments
                        if msg.command == mavutil.mavlink.MAV_CMD_COMPONENT_ARM_DISARM:
                            if msg.result == mavutil.mavlink.MAV_RESULT_ACCEPTED:
                                print(f"[MAVLinkThread] ✅ ARM/DISARM command ACCEPTED")
                                
                            elif msg.result == mavutil.mavlink.MAV_RESULT_DENIED:
                                print(f"[MAVLinkThread] ❌ ARM/DISARM command DENIED (result: {msg.result})")
                                
                            elif msg.result == mavutil.mavlink.MAV_RESULT_FAILED:
                                print(f"[MAVLinkThread] ❌ ARM/DISARM command FAILED (result: {msg.result})")
                                
                            elif msg.result == mavutil.mavlink.MAV_RESULT_TEMPORARILY_REJECTED:
                                print(f"[MAVLinkThread] ⚠️ ARM/DISARM command TEMPORARILY_REJECTED")
                            
                            else:
                                print(f"[MAVLinkThread] ⚠️ ARM/DISARM unknown result: {msg.result}")

                    # ========== GLOBAL_POSITION_INT - GPS Position ==========
                    elif msg_type == "GLOBAL_POSITION_INT":
                        new_lat = msg_dict['lat'] / 1e7
                        new_lon = msg_dict['lon'] / 1e7
                        new_alt = msg_dict['alt'] / 1000.0
                        new_rel_alt = msg_dict['relative_alt'] / 1000.0

                        if (
                            self.current_telemetry_components['lat'] != new_lat
                            or self.current_telemetry_components['lon'] != new_lon
                            or self.current_telemetry_components['alt'] != new_alt
                            or self.current_telemetry_components['rel_alt'] != new_rel_alt
                        ):
                            self.current_telemetry_components.update({
                                'lat': new_lat,
                                'lon': new_lon,
                                'alt': new_alt,
                                'rel_alt': new_rel_alt,
                            })
                            telemetry_component_changed = True

                    # ========== ATTITUDE - Roll/Pitch/Yaw ==========
                    elif msg_type == "ATTITUDE":
                        new_roll = math.degrees(msg_dict['roll'])
                        new_pitch = math.degrees(msg_dict['pitch'])
                        new_yaw = math.degrees(msg_dict['yaw'])
                        if (
                            self.current_telemetry_components['roll'] != new_roll
                            or self.current_telemetry_components['pitch'] != new_pitch
                            or self.current_telemetry_components['yaw'] != new_yaw
                        ):
                            self.current_telemetry_components.update({
                                'roll': new_roll,
                                'pitch': new_pitch,
                                'yaw': new_yaw,
                            })
                            telemetry_component_changed = True

                    # ========== VFR_HUD - Speed & Heading ==========
                    elif msg_type == "VFR_HUD":
                        new_heading = msg_dict['heading']
                        new_groundspeed = msg_dict['groundspeed']
                        new_airspeed = msg_dict['airspeed']
                        if (
                            self.current_telemetry_components['heading'] != new_heading
                            or self.current_telemetry_components['groundspeed'] != new_groundspeed
                            or self.current_telemetry_components['airspeed'] != new_airspeed
                        ):
                            self.current_telemetry_components.update({
                                'heading': new_heading,
                                'groundspeed': new_groundspeed,
                                'airspeed': new_airspeed,
                            })
                            telemetry_component_changed = True

                    # ========== SYS_STATUS - Battery Info ==========
                    elif msg_type == "SYS_STATUS":
                        new_battery_remaining = msg_dict.get('battery_remaining')
                        new_voltage_battery = msg_dict.get('voltage_battery')
                        new_current_battery = msg_dict.get('current_battery')

                        if new_voltage_battery not in (None, 65535):
                            new_voltage_battery /= 1000.0
                        else:
                            new_voltage_battery = None

                        if new_current_battery not in (None, -1):
                            new_current_battery /= 100.0
                        else:
                            new_current_battery = None

                        if new_battery_remaining == -1:
                            new_battery_remaining = None

                        if (
                            self.current_telemetry_components['battery_remaining'] != new_battery_remaining
                            or self.current_telemetry_components['voltage_battery'] != new_voltage_battery
                            or self.current_telemetry_components['current_battery'] != new_current_battery
                        ):
                            self.current_telemetry_components.update({
                                'battery_remaining': new_battery_remaining,
                                'voltage_battery': new_voltage_battery,
                                'current_battery': new_current_battery,
                            })
                            telemetry_component_changed = True

                    # ========== STATUSTEXT - Status Messages ==========
                    elif msg_type == "STATUSTEXT":
                        self.statusTextChanged.emit(msg.text)

                    # ==========================================
                    # ✅ PARAM_VALUE - Parameter Messages (FIXED)
                    # ==========================================
                    elif msg_type == "PARAM_VALUE":
                        param_msg_count += 1
                        
                        # Detailed logging for first 10 parameters
                        if param_msg_count <= 10:
                            try:
                                # ✅ Handle both bytes and string
                                param_id = msg.param_id
                                if isinstance(param_id, bytes):
                                    param_id = param_id.decode('utf-8').strip('\x00')
                                elif isinstance(param_id, str):
                                    param_id = param_id.strip('\x00')
                                else:
                                    param_id = str(param_id).strip('\x00')
                                
                                param_value = msg.param_value
                                param_index = msg.param_index
                                param_count = msg.param_count
                                
                                print(f"[MAVLinkThread] 📥 PARAM_VALUE #{param_msg_count}:")
                                print(f"  - ID: {param_id}")
                                print(f"  - Value: {param_value}")
                                print(f"  - Index: {param_index}/{param_count}")
                            except Exception as e:
                                print(f"[MAVLinkThread] ⚠️ Error parsing param: {e}")
                                import traceback
                                traceback.print_exc()
                        
                        # Progress updates every 100 parameters (reduced logging)
                        if param_msg_count % 100 == 0:
                            print(f"[MAVLinkThread] 📥 Received {param_msg_count} PARAM_VALUE messages so far")
                        
                        # Route to DroneCommander
                        if self.drone_commander is not None:
                            try:
                                self.drone_commander.add_parameter_to_queue(msg)
                                
                                # Confirm routing for first few
                                if param_msg_count <= 5:
                                    print(f"[MAVLinkThread] ✅ Routed to DroneCommander queue")
                                    
                            except Exception as e:
                                print(f"[MAVLinkThread] ❌ Error routing parameter: {e}")
                                import traceback
                                traceback.print_exc()
                        else:
                            # This is a critical error!
                            if param_msg_count == 1:
                                print("[MAVLinkThread] ❌ CRITICAL: drone_commander is None!")
                                print("[MAVLinkThread] ❌ Parameters cannot be collected!")
                                print("[MAVLinkThread] ❌ Make sure to pass drone_commander when creating MAVLinkThread")

                    # ========== EMIT TELEMETRY UPDATE ==========
                    if telemetry_component_changed:
                        self.telemetryUpdated.emit(self.current_telemetry_components.copy())

            except Exception as e:
                print(f"[MAVLinkThread] Error reading telemetry: {e}")
                import traceback
                traceback.print_exc()
                # Stop gracefully instead of crashing
                self.running = False
                if hasattr(self, "on_disconnect_callback") and self.on_disconnect_callback:
                    self.on_disconnect_callback()
                time.sleep(0.1)

    def stop(self):
        print("[MAVLinkThread] Stopping thread...")
        self.running = False
        self.quit()
        self.wait()
        print("[MAVLinkThread] Thread stopped.")