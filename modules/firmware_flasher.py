#!/usr/bin/env python3
"""
Firmware Flasher Backend Module
Integrates uploader.py functionality with PyQt5 for QML frontend
"""

import os
import sys
import time
import threading
from pathlib import Path
from PyQt5.QtCore import QObject, pyqtSignal, pyqtSlot, QTimer

# Import the uploader module
try:
    import uploader_2
    UPLOADER_AVAILABLE = True
except ImportError:
    UPLOADER_AVAILABLE = False
    print("⚠️ uploader.py not found in path")


class FirmwareFlasher(QObject):
    """Backend for firmware flashing with QML integration"""
    
    # Signals for QML
    flashingStarted = pyqtSignal()
    flashingProgress = pyqtSignal(int, str)  # progress, message
    flashingCompleted = pyqtSignal(bool, str)  # success, message
    bootloaderDetected = pyqtSignal(str, int, int, int)  # port, board_type, board_rev, bl_rev
    portListUpdated = pyqtSignal(list)  # available ports
    logMessage = pyqtSignal(str, str)  # message, severity
    
    def __init__(self, parent=None):
        super().__init__(parent)
        
        self.is_flashing = False
        self.cancel_requested = False
        self.flash_thread = None
        self.uploader_instance = None
        
        # Drone configurations with passwords
        self.drone_configs = {
            "Hexacopter": {
                "password": "hexa123",
                "board_id": 9,
                "description": "Hexacopter (6 motors) - FMUv3 compatible"
            },
            "Quadcopter": {
                "password": "quad456",
                "board_id": 50,
                "description": "Quadcopter (4 motors) - FMUv5 compatible"
            },
            "Octocopter": {
                "password": "octo789",
                "board_id": 11,
                "description": "Octocopter (8 motors) - FMUv4 compatible"
            },
            "Fixed-Wing": {
                "password": "wing321",
                "board_id": 13,
                "description": "Fixed-Wing aircraft - FMUv2 compatible"
            },
            "VTOL": {
                "password": "vtol654",
                "board_id": 14,
                "description": "VTOL (Vertical Take-Off and Landing)"
            }
        }
        
        # Flash settings
        self.baud_bootloader = 115200
        self.baud_bootloader_flash = 921600
        self.baud_flightstack = [57600, 115200]
        
        if not UPLOADER_AVAILABLE:
            self.logMessage.emit("⚠️ Uploader module not available", "error")
    
    @pyqtSlot(str, result=str)
    def getDroneDescription(self, drone_type):
        """Get description for a drone type"""
        if drone_type in self.drone_configs:
            return self.drone_configs[drone_type]["description"]
        return "Unknown drone type"
    
    @pyqtSlot(str, str, result=bool)
    def validatePassword(self, drone_type, password):
        """Validate password for selected drone type"""
        if drone_type in self.drone_configs:
            return self.drone_configs[drone_type]["password"] == password
        return False
    
    @pyqtSlot(result=list)
    def getAvailablePorts(self):
        """Get list of available serial ports"""
        if not UPLOADER_AVAILABLE:
            return []
        
        try:
            args = type('Args', (), {
                'port': None,
                'baud_bootloader': self.baud_bootloader,
                'baud_flightstack': str(self.baud_flightstack[0]),
                'baud_bootloader_flash': self.baud_bootloader_flash
            })()
            
            ports = uploader_2.ports_to_try(args)
            self.portListUpdated.emit(ports)
            return ports
        except Exception as e:
            self.logMessage.emit(f"Error getting ports: {e}", "error")
            return []
    
    @pyqtSlot(str)
    def identifyBoard(self, port):
        """Identify board on the specified port"""
        if not UPLOADER_AVAILABLE:
            self.logMessage.emit("Uploader module not available", "error")
            return
        
        def identify_thread():
            try:
                self.logMessage.emit(f"🔍 Identifying board on {port}...", "info")
                
                up = uploader_2.uploader(
                    port,
                    self.baud_bootloader,
                    self.baud_flightstack,
                    self.baud_bootloader_flash,
                    no_extf=False,
                    force_erase=False,
                    identify_only=True
                )
                
                if uploader_2.find_bootloader(up, port):
                    self.bootloaderDetected.emit(
                        port,
                        up.board_type,
                        up.board_rev,
                        up.bl_rev
                    )
                    self.logMessage.emit(
                        f"✅ Found board: Type={up.board_type}, Rev={up.board_rev}, BL={up.bl_rev}",
                        "success"
                    )
                else:
                    self.logMessage.emit("❌ No bootloader found", "error")
                
                up.close()
                
            except Exception as e:
                self.logMessage.emit(f"Error identifying board: {e}", "error")
        
        thread = threading.Thread(target=identify_thread, daemon=True)
        thread.start()
    
    @pyqtSlot(str, str, str, bool, int)
    def flashFirmware(self, port, firmware_path, drone_type, force_erase, boot_delay):
        """Flash firmware to the board"""
        if not UPLOADER_AVAILABLE:
            self.logMessage.emit("Uploader module not available", "error")
            return
        
        if self.is_flashing:
            self.logMessage.emit("Flashing already in progress", "warning")
            return
        
        # Validate drone type
        if drone_type not in self.drone_configs:
            self.logMessage.emit("Invalid drone type selected", "error")
            return
        
        # Check firmware file
        if not os.path.exists(firmware_path):
            self.logMessage.emit(f"Firmware file not found: {firmware_path}", "error")
            return
        
        self.is_flashing = True
        self.cancel_requested = False
        self.flashingStarted.emit()
        
        def flash_thread():
            try:
                self.logMessage.emit("🚀 Starting firmware flash process...", "info")
                self.flashingProgress.emit(5, "Loading firmware file...")
                
                # Load firmware
                fw = uploader_2.firmware(firmware_path)
                expected_board_id = self.drone_configs[drone_type]["board_id"]
                
                self.logMessage.emit(
                    f"📦 Loaded firmware for board {fw.property('board_id')}, size: {fw.property('image_size')} bytes",
                    "info"
                )
                self.flashingProgress.emit(10, "Firmware loaded successfully")
                
                if self.cancel_requested:
                    self._cancel_flash("Cancelled by user")
                    return
                
                # Create uploader instance
                self.flashingProgress.emit(15, "Connecting to bootloader...")
                self.logMessage.emit("🔌 Attempting to connect to bootloader...", "info")
                
                up = uploader_2.uploader(
                    port,
                    self.baud_bootloader,
                    self.baud_flightstack,
                    self.baud_bootloader_flash,
                    no_extf=False,
                    force_erase=force_erase,
                    identify_only=False
                )
                
                self.uploader_instance = up
                
                if self.cancel_requested:
                    up.close()
                    self._cancel_flash("Cancelled by user")
                    return
                
                # Find bootloader
                self.flashingProgress.emit(20, "Searching for bootloader...")
                max_attempts = 10
                found = False
                
                for attempt in range(max_attempts):
                    if self.cancel_requested:
                        up.close()
                        self._cancel_flash("Cancelled by user")
                        return
                    
                    self.logMessage.emit(f"🔍 Bootloader detection attempt {attempt + 1}/{max_attempts}...", "info")
                    
                    if uploader_2.find_bootloader(up, port):
                        found = True
                        break
                    
                    time.sleep(0.5)
                
                if not found:
                    up.close()
                    self._flash_error("Failed to find bootloader. Please reboot the board.")
                    return
                
                self.flashingProgress.emit(30, "Bootloader detected")
                self.logMessage.emit(
                    f"✅ Bootloader found: Type={up.board_type}, Rev={up.board_rev}, BL Rev={up.bl_rev}",
                    "success"
                )
                
                if self.cancel_requested:
                    up.close()
                    self._cancel_flash("Cancelled by user")
                    return
                
                # Verify board compatibility
                self.flashingProgress.emit(35, "Verifying board compatibility...")
                
                if up.board_type != expected_board_id:
                    board_name = up.board_name_for_board_id(up.board_type)
                    expected_name = up.board_name_for_board_id(expected_board_id)
                    
                    self.logMessage.emit(
                        f"⚠️ Board mismatch: Found {board_name} (ID={up.board_type}), "
                        f"expected {expected_name} (ID={expected_board_id})",
                        "warning"
                    )
                
                if self.cancel_requested:
                    up.close()
                    self._cancel_flash("Cancelled by user")
                    return
                
                # Start flashing
                self.flashingProgress.emit(40, "Erasing flash memory...")
                self.logMessage.emit("🗑️ Erasing flash memory...", "info")
                
                # Upload firmware
                self.flashingProgress.emit(50, "Uploading firmware...")
                self.logMessage.emit("📤 Uploading firmware to board...", "info")
                
                # Set boot delay if specified
                boot_delay_val = boot_delay if boot_delay > 0 else None
                
                # Perform upload
                up.upload(fw, force=True, boot_delay=boot_delay_val)
                
                if self.cancel_requested:
                    up.close()
                    self._cancel_flash("Cancelled during flash")
                    return
                
                self.flashingProgress.emit(100, "Firmware flashed successfully!")
                self.logMessage.emit("✅ Firmware flash completed successfully!", "success")
                self.flashingCompleted.emit(True, "Firmware uploaded successfully")
                
            except Exception as e:
                error_msg = str(e)
                self.logMessage.emit(f"❌ Flash error: {error_msg}", "error")
                self._flash_error(error_msg)
            
            finally:
                self.is_flashing = False
                self.uploader_instance = None
        
        self.flash_thread = threading.Thread(target=flash_thread, daemon=True)
        self.flash_thread.start()
    
    @pyqtSlot()
    def cancelFlashing(self):
        """Cancel ongoing flashing operation"""
        if self.is_flashing:
            self.logMessage.emit("🛑 Cancelling flash operation...", "warning")
            self.cancel_requested = True
    
    def _cancel_flash(self, reason):
        """Handle flash cancellation"""
        self.is_flashing = False
        self.flashingProgress.emit(0, f"Cancelled: {reason}")
        self.flashingCompleted.emit(False, reason)
        self.logMessage.emit(f"❌ Flash cancelled: {reason}", "warning")
    
    def _flash_error(self, error_msg):
        """Handle flash error"""
        self.is_flashing = False
        self.flashingProgress.emit(0, "Flash failed")
        self.flashingCompleted.emit(False, error_msg)
    
    def cleanup(self):
        """Cleanup resources"""
        self.cancel_requested = True
        
        if self.uploader_instance:
            try:
                self.uploader_instance.close()
            except:
                pass
        
        if self.flash_thread and self.flash_thread.is_alive():
            self.flash_thread.join(timeout=2.0)
        
        self.is_flashing = False
        self.logMessage.emit("🧹 Firmware flasher cleaned up", "info")