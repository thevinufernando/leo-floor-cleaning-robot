import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class SimulationService {
  Timer? _timer;
  final DocumentReference _docRef = FirebaseFirestore.instance
      .collection('robots')
      .doc('LEO_001');

  /// Starts a background clock that directly modifies cloud values in Firestore
  void startBatteryStream({
    required bool isCleaning,
    required bool isCharging,
    required int currentBattery,
    // Note: We keep the parameter definition intact so your home_page.dart doesn't throw compilation errors!
    required Function(int) onBatteryChanged,
  }) {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      // 1. Fetch the absolute freshest state from the cloud to prevent race conditions
      var snapshot = await _docRef.get();
      if (!snapshot.exists) return;

      var robotData = snapshot.data() as Map<String, dynamic>;
      int cloudBattery = robotData['batteryLevel'] ?? currentBattery;
      bool cloudCleaning = robotData['isCleaning'] ?? isCleaning;
      bool cloudCharging = robotData['isCharging'] ?? isCharging;

      // 🔥 CASE A: Robot is actively cleaning -> Drain cloud battery
      if (cloudCleaning && !cloudCharging && cloudBattery > 0) {
        cloudBattery -= 1;

        // Push update directly to the cloud
        await _docRef.update({'batteryLevel': cloudBattery});

        // Trigger automatic low battery safety cut-off on the cloud if it hits 15%
        if (cloudBattery <= 15) {
          await _docRef.update({'isCleaning': false, 'isRobotStuck': false});
          stopBatteryStream();
        }
      }
      // 🔌 CASE B: Robot is charging -> Fill cloud battery up to 100%
      else if (cloudCharging && cloudBattery < 100) {
        cloudBattery += 1;

        // Push update directly to the cloud
        await _docRef.update({'batteryLevel': cloudBattery});

        // Turn off charging flag automatically once completely filled
        if (cloudBattery >= 100) {
          await _docRef.update({'batteryLevel': 100, 'isCharging': false});
          stopBatteryStream();
        }
      }
    });
  }

  /// Turns off the background clock loop completely
  void stopBatteryStream() {
    _timer?.cancel();
  }

  /// Simulates LEO's onboard microcontroller executing firmware diagnostic logic
  Future<bool> runHardwareDiagnostics() async {
    // Mimics the real transmission delay to the physical robot's ESP32/Raspberry Pi
    await Future.delayed(const Duration(seconds: 3));

    // Once the diagnostics pass, we can also clear the error log on the cloud if needed
    return true;
  }
}
