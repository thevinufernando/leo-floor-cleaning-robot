import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class AddSpaceWizardScreen extends StatefulWidget {
  const AddSpaceWizardScreen({super.key});

  @override
  State<AddSpaceWizardScreen> createState() => _AddSpaceWizardScreenState();
}

class _AddSpaceWizardScreenState extends State<AddSpaceWizardScreen> {
  final TextEditingController _nameController = TextEditingController();
  int _currentStep = 1; // 1: Scanning, 2: Naming, 3: Saving
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        // Clean up cloud state variables if the user backs out prematurely
        await FirebaseFirestore.instance
            .collection('robots')
            .doc('LEO_001')
            .update({
              'request_new_space': false,
              'robot_scanning_status': 'mapping',
            });
      },
      child: Scaffold(
        backgroundColor: themeProvider.scaffoldBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_rounded,
              color: themeProvider.textColor,
            ),
            onPressed: () async {
              // Also clean up variables during an explicit back button press
              await FirebaseFirestore.instance
                  .collection('robots')
                  .doc('LEO_001')
                  .update({
                    'request_new_space': false,
                    'robot_scanning_status': 'mapping',
                  });
              if (!mounted) return;
              Navigator.pop(context);
            },
          ),
          title: Text(
            'Map Expansion',
            style: TextStyle(
              color: themeProvider.textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    (isDark ? const Color(0xFF162534) : Colors.grey[200]!)
                        .withValues(alpha: 0.8),
                    (isDark ? const Color(0xFF0D161F) : Colors.grey[100]!)
                        .withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_currentStep == 1) _buildScanningStep(),
                  if (_currentStep == 2) _buildNamingStep(),
                  if (_currentStep == 3) _buildSavingStep(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Replace the old _buildScanningStep() inside add_space_wizard.dart with this:
  Widget _buildScanningStep() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('robots')
          .doc('LEO_001')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          var robotData = snapshot.data!.data() as Map<String, dynamic>;
          String scanStatus = robotData['robot_scanning_status'] ?? 'mapping';

          // 🤖 The Magic Moment: If the robot finishes its wall-following loop,
          // it updates the database, and the app instantly moves to the naming step!
          if (scanStatus == 'success') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _currentStep = 2; // Jump to Naming Step automatically
              });
            });
          }
        }

        final themeProvider = Provider.of<ThemeProvider>(context);

        return Column(
          children: [
            SizedBox(
              height: 80,
              width: 80,
              child: CircularProgressIndicator(
                color: themeProvider.accentColor,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'LEO is Scanning Room...',
              style: TextStyle(
                color: themeProvider.textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Following wall boundaries via LiDAR telemetry. Waiting for robot loop closure...',
              textAlign: TextAlign.center,
              style: TextStyle(color: themeProvider.subTextColor, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // Manual Override Button (User decides to end scan early)
            TextButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('robots')
                    .doc('LEO_001')
                    .update({'robot_scanning_status': 'success'});
              },
              child: Text(
                'Force Stop & Save Current Area',
                style: TextStyle(
                  color: themeProvider.accentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNamingStep() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.edit_location_alt_rounded,
          color: themeProvider.accentColor,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          'Name New Space',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: themeProvider.textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _nameController,
          style: TextStyle(color: themeProvider.textColor),
          decoration: InputDecoration(
            hintText: 'e.g., Dining Area, Balcony',
            hintStyle: TextStyle(
              color: themeProvider.subTextColor.withValues(alpha: 0.5),
            ),
            filled: true,
            fillColor: themeProvider.surfaceBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: themeProvider.accentColor,
          ),
          onPressed: () async {
            final String newSpaceName = _nameController.text.trim().isNotEmpty
                ? _nameController.text.trim()
                : 'New Custom Space';

            setState(() => _currentStep = 3);

            // Push finalized registration data to the cloud document
            await FirebaseFirestore.instance
                .collection('robots')
                .doc('LEO_001')
                .update({
                  'request_new_space': false,
                  'robot_scanning_status': 'mapping',
                  'rooms': FieldValue.arrayUnion([
                    {'name': newSpaceName, 'color': 'cyan'},
                  ]),
                });

            if (!mounted) return;
            // Close the wizard navigation deck view frames back to the primary layout deck safely
            Navigator.pop(context);

            // 1. Establish a unique new document reference code inside our live missions history logs collection
            final newMissionRef = FirebaseFirestore.instance
                .collection('robots')
                .doc('LEO_001')
                .collection('missions')
                .doc();

            // 2. Update the root robot document parameters to fire active cleaning loops across all screen viewports
            await FirebaseFirestore.instance
                .collection('robots')
                .doc('LEO_001')
                .update({
                  'isCleaning': true,
                  'current_action': 'mapping_new_space',
                  'isRobotStuck': false,
                  'isDocking': false,
                  'isCharging': false,
                  'isEmergencyStopped': false,
                  'current_active_mission_id': newMissionRef.id,
                });

            // 3. Write a placeholder history card entry containing our newly typed custom space name variable string
            await newMissionRef.set({
              'zone': newSpaceName,
              'type': 'Mapping Cycle',
              'timestamp': FieldValue.serverTimestamp(),
              'isSuccess': true,
              'statusMessage': 'Running...',
              'area': '25 m²',
              'duration': '0 min',
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Mapping Sequence Initialized: LEO exploring $newSpaceName...',
                ),
                backgroundColor: themeProvider.accentColor,
              ),
            );
          },
          child: Text(
            'Add to Map',
            style: TextStyle(color: isDark ? Colors.black87 : Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildSavingStep() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Column(
      children: [
        const CircularProgressIndicator(color: Colors.greenAccent),
        const SizedBox(height: 24),
        Text(
          'Updating Map Grid...',
          style: TextStyle(
            color: themeProvider.textColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
