import 'package:first_app_test/add_space_wizard.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:first_app_test/spot_clean_wizard.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  int batteryLevel = 100;
  double coverageSqM = 51.0;
  int cleaningTimeMin = 83;
  int dustbinPercent = 72;
  List<dynamic> fetchedRooms = [];
  double mapScale = 1.0;
  bool isCleaningState = false;
  bool isEmergencyState = false;
  bool isChargingState = false;
  DateTime? _mapMissionStartTime;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('robots')
          .doc('LEO_001')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          var robotData = snapshot.data!.data() as Map<String, dynamic>;
          batteryLevel = robotData['batteryLevel'] ?? batteryLevel;
          coverageSqM =
              (robotData['coverage_sq_m'] as num?)?.toDouble() ?? coverageSqM;
          cleaningTimeMin = robotData['runtime_minutes'] ?? cleaningTimeMin;
          dustbinPercent = robotData['dustbin_percent'] ?? dustbinPercent;
          fetchedRooms = robotData['rooms'] ?? [];
          isCleaningState = robotData['isCleaning'] ?? isCleaningState;
          isEmergencyState =
              robotData['isEmergencyStopped'] ?? isEmergencyState;
          isChargingState = robotData['isCharging'] ?? isChargingState;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: _buildMetricsRow(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: _buildPremiumMapCanvas(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: _buildControlSection(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SPATIAL TELEMETRY',
                style: TextStyle(
                  color: themeProvider
                      .accentColor, // Updated to link with active Highlight Theme
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Live Environment Map',
                style: TextStyle(
                  color: themeProvider.textColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final dividerColor = themeProvider.isDarkMode
        ? Colors.white10
        : Colors.black12;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildMetricItem(
          '${coverageSqM.toStringAsFixed(1)} m²',
          'Cleaning Area',
        ),
        Container(width: 1, height: 24, color: dividerColor),
        _buildMetricItem('$batteryLevel%', 'Battery Level'),
        Container(width: 1, height: 24, color: dividerColor),
        _buildMetricItem(
          cleaningTimeMin >= 60
              ? '${cleaningTimeMin ~/ 60} min ${cleaningTimeMin % 60} sec'
              : '$cleaningTimeMin sec',
          'Cleaning Time',
        ),
      ],
    );
  }

  Widget _buildMetricItem(String primaryValue, String subLabel) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          primaryValue,
          style: TextStyle(
            color: themeProvider.textColor,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subLabel,
          style: TextStyle(
            color: themeProvider.subTextColor,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumMapCanvas() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Container(
      width: double.infinity,
      height: 380,
      decoration: BoxDecoration(
        color: themeProvider.cardBg, // Links context surface base safely
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : Colors.black12,
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: GestureDetector(
        onTapUp: (details) {
          final double clickX = details.localPosition.dx;
          final double clickY = details.localPosition.dy;
          const double mapCanvasHeight = 380.0;
          final double w = MediaQuery.of(context).size.width - 32;

          for (int i = 0; i < fetchedRooms.length; i++) {
            double topOffset = mapCanvasHeight * (0.1 + (i * 0.22)) * mapScale;
            double bottomOffset =
                mapCanvasHeight * (0.3 + (i * 0.22)) * mapScale;
            if (bottomOffset > mapCanvasHeight) bottomOffset = mapCanvasHeight;

            double leftBound = w * 0.05 * mapScale;
            double rightBound = w * 0.70 * mapScale;

            if (clickX >= leftBound &&
                clickX <= rightBound &&
                clickY >= topOffset &&
                clickY <= bottomOffset) {
              _showRoomManagementSheet(i, fetchedRooms[i]);
              break;
            }
          }
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.03,
                child: GridPaper(
                  color: themeProvider.accentColor,
                  divisions: 1,
                  subdivisions: 1,
                  interval: (30 * mapScale).clamp(10, 200),
                  child: Container(),
                ),
              ),
            ),
            if (fetchedRooms.isEmpty)
              Positioned.fill(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.explore_rounded,
                        color: themeProvider.accentColor,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'ENVIRONMENT UNMAPPED',
                        style: TextStyle(
                          color: themeProvider.textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Please initiate the global mapping mission sequence.',
                        style: TextStyle(
                          color: themeProvider.subTextColor,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: CustomPaint(
                    painter: ApartmentMapVectorPainter(
                      roomsList: fetchedRooms,
                      scale: mapScale,
                      accentColor: themeProvider.accentColor,
                      labelColor: themeProvider
                          .textColor, // Added dynamic contrast label tracker
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 105 * mapScale,
                top: 155 * mapScale,
                child: Container(
                  width: 16,
                  height: 12,
                  decoration: BoxDecoration(
                    color: themeProvider.accentColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: themeProvider.accentColor,
                        blurRadius: 12,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: CircleAvatar(
                      radius: 2,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
            Positioned(
              right: 16,
              bottom: 32,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => setState(() {
                      if (mapScale < 2.0) mapScale += 0.15;
                    }),
                    child: _buildFloatingToolButton(Icons.add_rounded),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setState(() {
                      if (mapScale > 0.6) mapScale -= 0.15;
                    }),
                    child: _buildFloatingToolButton(Icons.remove_rounded),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => setState(() => mapScale = 1.0),
                    child: _buildFloatingToolButton(
                      Icons.center_focus_strong_rounded,
                      isAccent: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingToolButton(IconData icon, {bool isAccent = false}) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final accentColor = themeProvider.accentColor;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isAccent
            ? accentColor
            : (isDark ? const Color(0xFF101922) : Colors.grey[200]!),
        shape: BoxShape.circle,
        border: Border.all(
          color: isAccent
              ? Colors.transparent
              : (isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.06)),
          width: 1,
        ),
      ),
      child: Icon(
        icon,
        size: 18,
        color: isAccent
            ? Colors.white
            : (isDark ? const Color(0xFF8E9AA6) : Colors.black54),
      ),
    );
  }

  Widget _buildControlSection() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final accentColor = themeProvider.accentColor;
    final bool canControl =
        batteryLevel >= 15 && !isChargingState && !isEmergencyState;
    final bool canModifySpaces = canControl && !isCleaningState;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: !canControl
              ? null
              : () async {
                  if (!canControl) return;
                  bool targetCleaningState = !isCleaningState;
                  if (!targetCleaningState) {
                    final robotDoc = await FirebaseFirestore.instance
                        .collection('robots')
                        .doc('LEO_001')
                        .get();
                    final robotData = robotDoc.data() as Map<String, dynamic>;
                    final String? activeMissionId =
                        robotData['current_active_mission_id'];

                    if (_mapMissionStartTime != null &&
                        activeMissionId != null) {
                      int elapsedSeconds = DateTime.now()
                          .difference(_mapMissionStartTime!)
                          .inSeconds;
                      double calculatedArea = elapsedSeconds * 0.4;
                      await FirebaseFirestore.instance
                          .collection('robots')
                          .doc('LEO_001')
                          .collection('missions')
                          .doc(activeMissionId)
                          .update({
                            'duration': elapsedSeconds < 60
                                ? '$elapsedSeconds sec'
                                : '${(elapsedSeconds / 60).floor()} min',
                            'area': '${calculatedArea.toStringAsFixed(1)} m²',
                            'statusMessage': 'Completed Successfully',
                          });
                    }
                    _mapMissionStartTime = null;
                  }

                  await FirebaseFirestore.instance
                      .collection('robots')
                      .doc('LEO_001')
                      .update({
                        'isCleaning': targetCleaningState,
                        'desired_state.isCleaning': targetCleaningState,
                        'isRobotStuck': false,
                        'isDocking': false,
                        'isCharging': false,
                      });
                },
          child: Container(
            height: 52,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: !canControl
                  ? (isDark ? const Color(0xFF1A2229) : Colors.grey[300]!)
                  : null,
              border: !canControl
                  ? Border.all(
                      color: isEmergencyState
                          ? Colors.redAccent.withOpacity(0.5)
                          : Colors.grey.withOpacity(0.5),
                      width: 1.5,
                    )
                  : null,
              gradient: !canControl
                  ? null
                  : LinearGradient(
                      colors: isCleaningState
                          ? [const Color(0xFFF39C12), const Color(0xFFD35400)]
                          : [
                              accentColor,
                              accentColor.withRed(
                                (accentColor.red - 40).clamp(0, 255),
                              ),
                            ],
                    ),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isEmergencyState
                        ? Icons.report_problem_rounded
                        : (isChargingState
                              ? Icons.battery_charging_full_rounded
                              : (batteryLevel < 15
                                    ? Icons.battery_alert_rounded
                                    : (isCleaningState
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded))),
                    color: !canControl
                        ? (isEmergencyState ? Colors.redAccent : Colors.grey)
                        : Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEmergencyState
                        ? 'System Locked (Emergency)'
                        : (isChargingState
                              ? 'Charging - Control Disabled'
                              : (batteryLevel < 15
                                    ? 'Battery Critically Low'
                                    : (isCleaningState
                                          ? 'Pause Mission'
                                          : 'Resume Mission'))),
                    style: TextStyle(
                      color: !canControl
                          ? (isEmergencyState ? Colors.redAccent : Colors.grey)
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Freestyle Custom Zone Button
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: !canModifySpaces
                ? null
                : () {
                    if (!canModifySpaces) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            SpotCleanWizardScreen(currentRooms: fetchedRooms),
                      ),
                    );
                  },
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: !canModifySpaces
                    ? Colors.grey.withOpacity(0.1)
                    : themeProvider.cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: !canModifySpaces
                      ? Colors.grey.withOpacity(0.3)
                      : accentColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    !canModifySpaces
                        ? Icons.lock_outline_rounded
                        : Icons.gesture_rounded,
                    color: !canModifySpaces
                        ? Colors.grey
                        : themeProvider.accentColor,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    !canModifySpaces
                        ? (isCleaningState
                              ? 'Blocked - Mission Active'
                              : (batteryLevel < 15
                                    ? 'Blocked - Low Battery'
                                    : 'Blocked - Charging Active'))
                        : 'Freestyle Spot Clean Zone',
                    style: TextStyle(
                      color: !canModifySpaces
                          ? Colors.grey
                          : themeProvider.textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Add Space Button Card Layout
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: !canModifySpaces
                ? null
                : () {
                    if (!canModifySpaces) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddSpaceWizardScreen(),
                      ),
                    );
                  },
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: !canModifySpaces
                    ? Colors.grey.withOpacity(0.1)
                    : themeProvider.cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isEmergencyState
                      ? Colors.redAccent.withOpacity(0.3)
                      : (!canModifySpaces
                            ? Colors.grey.withOpacity(0.3)
                            : accentColor.withOpacity(0.3)),
                  width: !canModifySpaces ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    !canModifySpaces
                        ? Icons.lock_outline_rounded
                        : Icons.add_location_alt_rounded,
                    color: isEmergencyState
                        ? Colors.redAccent
                        : (!canModifySpaces ? Colors.grey : accentColor),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEmergencyState
                        ? 'Blocked - Emergency Active'
                        : (!canModifySpaces
                              ? (isCleaningState
                                    ? 'Blocked - Mission Active'
                                    : (batteryLevel < 15
                                          ? 'Blocked - Low Battery'
                                          : 'Blocked - Charging Active'))
                              : 'Add New Environment Space'),
                    style: TextStyle(
                      color: isEmergencyState
                          ? Colors.redAccent
                          : (!canModifySpaces
                                ? Colors.grey
                                : themeProvider.textColor),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showRoomManagementSheet(int index, Map<String, dynamic> roomData) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor:
          themeProvider.cardBg, // Resolves hardcoded sheet overlay color bugs
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.cleaning_services_rounded,
                  color: Color(0xFF2ECC71),
                ),
                title: Text(
                  'Clean "${roomData['name']}" Only',
                  style: TextStyle(color: themeProvider.textColor),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final String dynamicRoomNameVar =
                      roomData['name'] ?? 'Unknown Space';
                  final newMissionRef = FirebaseFirestore.instance
                      .collection('robots')
                      .doc('LEO_001')
                      .collection('missions')
                      .doc();
                  _mapMissionStartTime = DateTime.now();

                  await FirebaseFirestore.instance
                      .collection('robots')
                      .doc('LEO_001')
                      .update({
                        'isCleaning': true,
                        'current_action':
                            'clean_room_${dynamicRoomNameVar.toLowerCase()}',
                        'isRobotStuck': false,
                        'isDocking': false,
                        'isCharging': false,
                        'isEmergencyStopped': false,
                        'current_active_mission_id': newMissionRef.id,
                      });

                  await newMissionRef.set({
                    'zone': dynamicRoomNameVar,
                    'type': 'Room Dispatch',
                    'timestamp': FieldValue.serverTimestamp(),
                    'isSuccess': true,
                    'statusMessage': 'Running...',
                    'area': '18 m²',
                    'duration': '14 min',
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Room Dispatch Synced: LEO traveling to $dynamicRoomNameVar...',
                      ),
                      backgroundColor: themeProvider.accentColor,
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.edit_rounded,
                  color: themeProvider.accentColor,
                ),
                title: Text(
                  'Rename "${roomData['name']}"',
                  style: TextStyle(color: themeProvider.textColor),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showRenameDialog(index, roomData['name']);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.redAccent,
                ),
                title: Text(
                  'Delete Space from Map',
                  style: TextStyle(color: themeProvider.textColor),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await FirebaseFirestore.instance
                      .collection('robots')
                      .doc('LEO_001')
                      .update({
                        'rooms': FieldValue.arrayRemove([roomData]),
                      });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRenameDialog(int index, String currentName) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final TextEditingController renameController = TextEditingController(
      text: currentName,
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: themeProvider.cardBg, // Context base layer override
          title: Text(
            'Rename Space',
            style: TextStyle(color: themeProvider.textColor),
          ),
          content: TextField(
            controller: renameController,
            style: TextStyle(color: themeProvider.textColor),
            decoration: InputDecoration(
              filled: true,
              fillColor: themeProvider.scaffoldBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (renameController.text.trim().isEmpty) return;
                List<dynamic> updatedList = List.from(fetchedRooms);
                updatedList[index]['name'] = renameController.text.trim();
                await FirebaseFirestore.instance
                    .collection('robots')
                    .doc('LEO_001')
                    .update({'rooms': updatedList});
                if (!mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

class ApartmentMapVectorPainter extends CustomPainter {
  final List<dynamic> roomsList;
  final double scale;
  final Color accentColor;
  final Color labelColor; // Accept contrast boundary colors from runtime setup

  ApartmentMapVectorPainter({
    required this.roomsList,
    required this.scale,
    required this.accentColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final Paint wallStrokePaint = Paint()
      ..color = accentColor.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final Paint obstacleFill = Paint()
      ..color = const Color(0xFFFF9F43).withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final Paint obstacleStroke = Paint()
      ..color = const Color(0xFFFF9F43).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (int i = 0; i < roomsList.length; i++) {
      var room = roomsList[i];
      String name = room['name'] ?? 'Unnamed Zone';
      String colorStr = room['color'] ?? 'blue';

      Color fillThemeColor = accentColor.withOpacity(0.1);
      if (colorStr == 'green')
        fillThemeColor = const Color(0xFF2ECC71).withOpacity(0.12);
      if (colorStr == 'cyan')
        fillThemeColor = const Color(0xFF00E5FF).withOpacity(0.15);

      final Paint fillPaint = Paint()
        ..color = fillThemeColor
        ..style = PaintingStyle.fill;

      if (room['points'] != null && (room['points'] as List).isNotEmpty) {
        final List<dynamic> pointsData = room['points'];
        final Path customRoomPath = Path();

        for (int p = 0; p < pointsData.length; p++) {
          List<dynamic> coordinates = pointsData[p];
          double targetX = w * (coordinates[0] as num).toDouble() * scale;
          double targetY = h * (coordinates[1] as num).toDouble() * scale;

          if (p == 0) {
            customRoomPath.moveTo(targetX, targetY);
          } else {
            customRoomPath.lineTo(targetX, targetY);
          }
        }
        customRoomPath.close();

        canvas.drawPath(customRoomPath, fillPaint);
        canvas.drawPath(customRoomPath, wallStrokePaint);

        List<dynamic> firstPt = pointsData[0];
        _renderLabel(
          canvas,
          name,
          Offset(
            (w * (firstPt[0] as num).toDouble() * scale) + 16,
            (h * (firstPt[1] as num).toDouble() * scale) + 12,
          ),
          labelColor, // Refactored dynamic text color visibility contract
        );
      } else {
        double topOffset = h * (0.1 + (i * 0.22)) * scale;
        double bottomOffset = h * (0.3 + (i * 0.22)) * scale;

        if (topOffset > h) continue;
        if (bottomOffset > h) bottomOffset = h;

        final Rect roomRect = Rect.fromLTRB(
          w * 0.05,
          topOffset,
          w * 0.75,
          bottomOffset,
        );

        canvas.drawRect(roomRect, fillPaint);
        canvas.drawRect(roomRect, wallStrokePaint);

        _renderLabel(
          canvas,
          name,
          Offset((w * 0.05) + 16, topOffset + 12),
          labelColor, // Refactored dynamic text color visibility contract
        );
      }

      if (room['obstacles'] != null) {
        final List<dynamic> obstaclesList = room['obstacles'];
        for (var obs in obstaclesList) {
          String label = obs['label'] ?? 'Object';

          double obsX = w * ((obs['x'] as num?)?.toDouble() ?? 0.0) * scale;
          double obsY = h * ((obs['y'] as num?)?.toDouble() ?? 0.0) * scale;
          double obsW = w * ((obs['w'] as num?)?.toDouble() ?? 0.0) * scale;
          double obsH = h * ((obs['h'] as num?)?.toDouble() ?? 0.0) * scale;

          final Rect obsRect = Rect.fromLTWH(obsX, obsY, obsW, obsH);

          canvas.drawRect(obsRect, obstacleFill);
          canvas.drawRect(obsRect, obstacleStroke);

          _renderLabel(
            canvas,
            label.toUpperCase(),
            Offset(obsX + 4, obsY + 4),
            const Color(0xFFFF9F43),
            fontSize: 8,
          );
        }
      }
    }
  }

  void _renderLabel(
    Canvas canvas,
    String text,
    Offset offset,
    Color textColor, {
    double fontSize = 11,
  }) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant ApartmentMapVectorPainter oldDelegate) {
    return oldDelegate.scale != scale ||
        oldDelegate.roomsList != roomsList ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.labelColor != labelColor;
  }
}
