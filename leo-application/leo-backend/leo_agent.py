#!/usr/bin/env python3
import os
import time
import math
import logging
import threading
from datetime import datetime, timezone
from google.cloud import firestore

# Configure structured project logs
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] (%(threadName)s) %(message)s"
)
logger = logging.getLogger("LEO_StateEngine")

class LeoStateDaemon:
    def __init__(self, document_path="robots/LEO_001"):
        if not os.environ.get("GOOGLE_APPLICATION_CREDENTIALS"):
            raise RuntimeError("Missing secret Firebase JSON credentials file configuration flag!")

        self.db = firestore.Client()
        self.doc_ref = self.db.document(document_path)
        self.is_running = True
        
        # Internal Hardware Flags
        self.battery_level = 100
        self.is_charging = False
        self.is_cleaning = False
        self.current_mode = "Auto Mode"
        self.current_action = ""
        self.is_emergency_stopped = False
        self.is_robot_stuck = False
        self.is_verifying_fault = False
        
        # Coordinates Tracking and Kinematics Simulation
        self.coords_x = 0.5          # Center map start
        self.coords_y = 0.5          # Center map start
        self.orientation_deg = 0.0   # Facing North start
        self.sim_step = 0.0          # Parametric step timer
        self.last_coords_change_time = time.time()

        # Volatile Run Metrics
        self.runtime_minutes = 0
        self.coverage_sq_m = 0.0
        self.run_start_time = None
        self.last_known_time = 0
        self.last_known_area = 0.0

    def start(self):
        logger.info("......Waking up LEO from cold boot... Initializing state machine daemon.")
        
        # 1. Start live Firestore snapshot listener
        self.listener_watch = self.doc_ref.on_snapshot(self._on_firestore_snapshot)
        
        # 2. Start core multi-threaded daemon control loop
        self.main_loop_thread = threading.Thread(
            target=self._daemon_loop,
            name="DaemonLoop",
            daemon=True
        )
        self.main_loop_thread.start()
        logger.info("......LEO State Machine Daemon successfully initialized and live.")

    def stop(self):
        self.is_running = False
        self.listener_watch.unsubscribe()
        logger.info("LEO Daemon terminated safely.")

    def _on_firestore_snapshot(self, doc_snapshot, changes, read_time):
        for doc in doc_snapshot:
            data = doc.to_dict()
            if not data: continue

            # Extract target desired state parameters
            desired = data.get("desired_state", {})
            
            db_is_cleaning = desired.get("isCleaning", data.get("isCleaning", False))
            db_current_mode = desired.get("currentMode", data.get("currentMode", "Auto Mode"))
            db_is_charging = data.get("isCharging", False)
            
            self.current_action = data.get("current_action", "")
            self.is_emergency_stopped = data.get("isEmergencyStopped", False)
            self.is_verifying_fault = data.get("isVerifyingFault", False)

            # RULE 1: HARDWARE UNPLUG SAFETY LOCKOUT (Unified 15% Threshold)
            if self.is_charging and not db_is_charging:
                if self.battery_level < 15:
                    logger.warning(f".....Safety Violation: Unplugged early at {self.battery_level}% (Floor: 15%). Re-engaging lock!")
                    self.doc_ref.update({"isCharging": True})
                    return
                else:
                    self.is_charging = False
                    logger.info("🔌 Charger manually disconnected. LEO is now ready to clean.")
            elif not self.is_charging and db_is_charging:
                self.is_charging = True
                logger.info(".....Power cord connection detected. Entering charging rest mode.")
            
            # RULE 2: CHARGING INTERLOCK TRAP
            if self.is_charging and db_is_cleaning:
                logger.warning("....Interlock Trap: Operational commands rejected while charging cable is connected.")
                self._force_cleaning_state_false()
                return

            # RULE 3: TWO-STAGE EMERGENCY STOP TRACK
            if self.is_emergency_stopped:
                if db_is_cleaning:
                    logger.warning(".....Safety Lockout: Emergency Stop is active. Command rejected.")
                    self._force_cleaning_state_false()
                
                # Rule 3.1: Intermediate Verification Stage
                if self.is_verifying_fault:
                    logger.info("🛠️ INTERMEDIATE STAGE: System fault reset hit. Awaiting physical chassis confirmation...")
                    self._simulate_physical_chassis_reset_press()
                return

            # RULE 4: HAZARD STUCK ENGINE ISOLATION
            if self.is_robot_stuck and db_is_cleaning:
                logger.warning(".....Hazard Lockout: Robot is stuck. Clear blockage on unit chassis to release.")
                self._force_cleaning_state_false()
                return

            # Process valid operational state transitions
            if db_is_cleaning != self.is_cleaning:
                self._handle_cleaning_transition(db_is_cleaning, db_current_mode)

    def _handle_cleaning_transition(self, start_cleaning: bool, mode: str):
        if start_cleaning:
            logger.info(f".....GO-TIME: Motors Engaged! Mode: [ARMED -> {mode}]")
            self.is_cleaning = True
            self.current_mode = mode
            self.run_start_time = time.time()
            
            # Reset trip metrics to absolute zero for the new clean cycle
            self.runtime_minutes = 0
            self.coverage_sq_m = 0.0
            self._push_state_update(is_cleaning=True, mode=mode, runtime=0, coverage=0.0)
        else:
            logger.info(".....PAUSE HIT: Halting motors. Saving current trip profile cache.")
            self.is_cleaning = False
            self.run_start_time = None
            
            # Cache the final metrics of the completed cycle
            self.last_known_time = self.runtime_minutes
            self.last_known_area = self.coverage_sq_m
            self._push_state_update(is_cleaning=False)

    def _force_cleaning_state_false(self):
        self.is_cleaning = False
        self.doc_ref.update({
            "isCleaning": False,
            "desired_state.isCleaning": False,
            "reported_state.isCleaning": False
        })

    def _push_state_update(self, is_cleaning=None, mode=None, runtime=None, coverage=None):
        payload = {}
        if is_cleaning is not None:
            payload["isCleaning"] = is_cleaning
            payload["reported_state.isCleaning"] = is_cleaning
        if mode is not None:
            payload["currentMode"] = mode
            payload["reported_state.currentMode"] = mode
        
        # Display live running metrics or hold steady onto the last known cache if stopped
        if self.is_cleaning:
            payload["runtime_minutes"] = int(self.runtime_minutes)
            payload["coverage_sq_m"] = round(self.coverage_sq_m, 2)
            payload["reported_state.x"] = self.coords_x
            payload["reported_state.y"] = self.coords_y
            payload["reported_state.orientation"] = self.orientation_deg
        else:
            payload["runtime_minutes"] = int(self.last_known_time)
            payload["coverage_sq_m"] = round(self.last_known_area, 2)
        
        if payload:
            self.doc_ref.update(payload)

    def _daemon_loop(self):
        tick_count = 0
        while self.is_running:
            try:
                # 1. Heartbeat Sync (every 8 seconds)
                if tick_count % 8 == 0:
                    self.doc_ref.update({"lastSeen": firestore.SERVER_TIMESTAMP})

                # 2. Check Automated Schedules Framework (every 60 seconds)
                if tick_count % 60 == 0:
                    self._check_automated_schedules()

                # 3. Stuck Logic Tracking (every 5 seconds)
                if tick_count % 5 == 0:
                    self._check_stuck_logic()

                # 4. Battery & Power Simulation (every 5 seconds for responsive demo scaling)
                if tick_count % 5 == 0:
                    self._simulate_battery_and_charging()

                # Accumulate and push trip metrics EVERY 1 SECOND while cleaning is true
                if self.is_cleaning:
                    self._accumulate_metrics()

            except Exception as e:
                logger.error(f"Error in Daemon Loop Tick: {e}")
            
            time.sleep(1)
            tick_count += 1

    def _check_automated_schedules(self):
        routines = self.doc_ref.collection("routines").get()
        now = datetime.now()
        current_day = now.isoweekday()  # Mon=1, Sun=7
        current_time_str = now.strftime("%H:%M")
        
        for routine_doc in routines:
            r_data = routine_doc.to_dict()
            if not r_data or not r_data.get("isActive", False): continue
            
            r_time = r_data.get("time", "")
            r_days = r_data.get("days", [])
            r_mode = r_data.get("mode", "Auto Mode")

            if r_time == current_time_str and (current_day in r_days):
                logger.info(f".....Automated routine match reached! Target Time: {r_time} | Mode: {r_mode}")
                
                # CRITICAL PRE-FLIGHT SAFETY FILTER
                if self.battery_level > 15 and not self.is_charging:
                    logger.info(".....Routine safety check passed. Launching autonomous mission.")
                    self.is_cleaning = True
                    self.current_mode = r_mode
                    self.run_start_time = time.time()
                    self.runtime_minutes = 0
                    self.coverage_sq_m = 0.0
                    
                    self.doc_ref.update({
                        "isCleaning": True,
                        "desired_state.isCleaning": True,
                        "reported_state.isCleaning": True,
                        "currentMode": r_mode,
                        "reported_state.currentMode": r_mode,
                        "runtime_minutes": 0,
                        "coverage_sq_m": 0.0
                    })
                else:
                    logger.warning(f".....Schedule bypassed: Safety constraints violated (Battery: {self.battery_level}%, Charging: {self.is_charging})")

    def _check_stuck_logic(self):
        if not self.is_cleaning: return
        
        now_time = time.time()
        # If coordinates tracking profile maps as static for > 30 seconds, fire warning
        if (now_time - self.last_coords_change_time) > 30:
            logger.error(".......HAZARD HAZARD: Robot stationary for >30 seconds! Triggering STUCK exception.")
            self.is_robot_stuck = True
            self.is_cleaning = False
            self.doc_ref.update({
                "isRobotStuck": True,
                "isCleaning": False,
                "reported_state.isCleaning": False
            })

    def _simulate_battery_and_charging(self):
        if self.is_charging:
            if self.battery_level < 100:
                self.battery_level += 5
                if self.battery_level > 100: self.battery_level = 100
                self.doc_ref.update({"batteryLevel": self.battery_level})
        else:
            if self.is_cleaning:
                self.battery_level -= 2
                
                # CRITICAL COMPLETE DEPLETION HIERARCHY
                if self.battery_level <= 0:
                    self.battery_level = 0
                    logger.critical(".......Battery Depleted Completely! Dropping system connection.")
                    self.is_cleaning = False
                    self.doc_ref.update({
                        "batteryLevel": 0,
                        "isCleaning": False,
                        "reported_state.isCleaning": False,
                        "lastCleanedTime": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M")
                    })
                    self.stop()
                    return
                
                if self.battery_level <= 15:
                    logger.warning(f".......Battery Alert: Capacity critically low at {self.battery_level}%")
                
                self.doc_ref.update({"batteryLevel": self.battery_level})

        # COLD-BOOT INTERLOCK GUARD
        if not self.is_charging and self.battery_level < 15:
            logger.warning(".......Safety Guard: Unplugged below 15% safety limit. Forcing charging constraints back to active.")
            self.is_charging = True
            self.doc_ref.update({"isCharging": True})

    def _accumulate_metrics(self):
        if not self.run_start_time: return
        
        # 1. Update operational timing metrics
        elapsed_seconds = int(time.time() - self.run_start_time)
        self.runtime_minutes = elapsed_seconds  
        
        # 2. Scale cleaning area metric relative to suction selection
        if self.current_mode == "Max Suction":
            self.coverage_sq_m += 0.12
        elif self.current_mode == "Eco Mode":
            self.coverage_sq_m += 0.05
        else:
            self.coverage_sq_m += 0.08
            
        # 3. Smooth kinematic position orbit path simulator bounding [0.2, 0.8]
        self.sim_step += 0.05
        self.coords_x = round(0.5 + 0.28 * math.sin(self.sim_step), 3)
        self.coords_y = round(0.5 + 0.28 * math.cos(self.sim_step * 1.3), 3)
        
        # Calculate dynamic directional angle vector mapping based on travel tangent
        dx = 0.28 * math.cos(self.sim_step)
        dy = -0.364 * math.sin(self.sim_step * 1.3)
        raw_heading = math.degrees(math.atan2(dy, dx))
        self.orientation_deg = round((raw_heading + 360) % 360, 1)
        
        # Refresh the change checker to prevent false stuck triggers while driving
        self.last_coords_change_time = time.time()
           
        self._push_state_update(runtime=self.runtime_minutes, coverage=self.coverage_sq_m)

    def _simulate_physical_chassis_reset_press(self):
        """Simulates technician inspecting the unit and manually pressing the physical chassis power button."""
        time.sleep(3)
        logger.info("........ MOCK SIMULATION: Physical power button pressed natively on LEO's hardware chassis.")
        logger.info(".........Physical verification clear! Flushing all cloud safety traps.")
        self.is_emergency_stopped = False
        self.is_verifying_fault = False
        self.is_robot_stuck = False
        self.doc_ref.update({
            "isEmergencyStopped": False,
            "isVerifyingFault": False,
            "isRobotStuck": False,
            "current_action": "ready_to_clean"
        })

if __name__ == "__main__":
    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "./firebase-key.json"
    daemon = LeoStateDaemon()
    try:
        daemon.start()
        while True: time.sleep(1)
    except KeyboardInterrupt:
        daemon.stop()