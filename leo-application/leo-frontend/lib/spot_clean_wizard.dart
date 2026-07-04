import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class SpotCleanWizardScreen extends StatefulWidget {
  final List<dynamic> currentRooms;
  const SpotCleanWizardScreen({super.key, required this.currentRooms});

  @override
  State<SpotCleanWizardScreen> createState() => _SpotCleanWizardScreenState();
}

class _MapDrawingPainter extends CustomPainter {
  final List<dynamic> roomsList;
  final List<Offset> lassoTrail;
  final Color textColor;
  final Color subTextColor;
  final Color accentColor;

  _MapDrawingPainter({
    required this.roomsList,
    required this.lassoTrail,
    required this.textColor,
    required this.subTextColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final Paint wallStroke = Paint()
      ..color = accentColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // 1. Draw base layout floor frames alongside text tags
    for (int i = 0; i < roomsList.length; i++) {
      var room = roomsList[i];
      String name = room['name'] ?? 'Unnamed Zone';

      double topOffset = h * (0.1 + (i * 0.22));
      double bottomOffset = h * (0.3 + (i * 0.22));
      if (bottomOffset > h) bottomOffset = h;

      final Rect roomRect = Rect.fromLTRB(
        w * 0.05,
        topOffset,
        w * 0.75,
        bottomOffset,
      );
      canvas.drawRect(roomRect, wallStroke);

      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: name,
          style: TextStyle(
            color: subTextColor.withValues(alpha: 0.5),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset((w * 0.05) + 12, topOffset + 10));
    }

    // 2. Draw user's live neon drawing lasso trail
    if (lassoTrail.length > 1) {
      final Paint lassoPaint = Paint()
        ..color = const Color(0xFF00E5FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final Path path = Path()..moveTo(lassoTrail[0].dx, lassoTrail[0].dy);
      for (int p = 1; p < lassoTrail.length; p++) {
        path.lineTo(lassoTrail[p].dx, lassoTrail[p].dy);
      }
      canvas.drawPath(path, lassoPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MapDrawingPainter oldDelegate) => true;
}

class _SpotCleanWizardScreenState extends State<SpotCleanWizardScreen> {
  List<Offset> drawingPoints = [];
  final GlobalKey _canvasKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: themeProvider.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: themeProvider.textColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Custom Zone Dispatch',
          style: TextStyle(
            color: themeProvider.textColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          if (drawingPoints.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => drawingPoints.clear()),
              child: const Text(
                'Clear',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Use your finger to draw a target boundary directly over the map canvas area below:',
              style: TextStyle(color: themeProvider.subTextColor, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Interactive Freestyle Drawing Box
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: themeProvider.cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior
                      .opaque, // ⚡ Force transparent areas to register touches instantly
                  onPanUpdate: (details) {
                    final RenderBox? renderBox =
                        _canvasKey.currentContext?.findRenderObject()
                            as RenderBox?;
                    if (renderBox == null) return;

                    final double boxWidth = renderBox.size.width;
                    final double boxHeight = renderBox.size.height;
                    final Offset localPos = details.localPosition;

                    bool pointValid = false;

                    // High-speed optimized loop checking boundary allocations
                    for (int i = 0; i < widget.currentRooms.length; i++) {
                      double topOffset = boxHeight * (0.1 + (i * 0.22));
                      double bottomOffset = boxHeight * (0.3 + (i * 0.22));
                      if (bottomOffset > boxHeight) bottomOffset = boxHeight;

                      double leftBound = boxWidth * 0.05;
                      double rightBound = boxWidth * 0.75;

                      if (localPos.dx >= leftBound &&
                          localPos.dx <= rightBound &&
                          localPos.dy >= topOffset &&
                          localPos.dy <= bottomOffset) {
                        pointValid = true;
                        break;
                      }
                    }

                    if (pointValid) {
                      setState(() {
                        drawingPoints.add(localPos);
                      });
                    }
                  },
                  child: SizedBox.expand(
                    child: CustomPaint(
                      key:
                          _canvasKey, // ⚡ Uses global tracking keys to optimize frame calculations
                      painter: _MapDrawingPainter(
                        roomsList: widget.currentRooms,
                        lassoTrail: drawingPoints,
                        textColor: themeProvider.textColor,
                        subTextColor: themeProvider.subTextColor,
                        accentColor: themeProvider.accentColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Confirmation Dispatch Action Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: drawingPoints.isEmpty
                      ? (isDark ? Colors.white10 : Colors.black12)
                      : themeProvider.accentColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: drawingPoints.isEmpty ? null : _dispatchZoneCommand,
                icon: Icon(
                  Icons.flash_on_rounded,
                  color: drawingPoints.isEmpty
                      ? Colors.grey
                      : (isDark ? Colors.black87 : Colors.white),
                  size: 18,
                ),
                label: Text(
                  'Dispatch LEO to Zone',
                  style: TextStyle(
                    color: drawingPoints.isEmpty
                        ? Colors.grey
                        : (isDark ? Colors.black87 : Colors.white),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _dispatchZoneCommand() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final robotDoc = await FirebaseFirestore.instance
        .collection('robots')
        .doc('LEO_001')
        .get();
    final robotData = robotDoc.data() as Map<String, dynamic>;
    final bool isLockedOut = robotData['isEmergencyStopped'] ?? false;

    if (isLockedOut) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Commands are rejected until the emergency fault is cleared on the home screen.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    navigator.pop();

    List<Map<String, double>> normalizedCoords = [];

    for (int i = 0; i < drawingPoints.length; i += 12) {
      Offset offset = drawingPoints[i];
      normalizedCoords.add({
        'x': (offset.dx / 300.0).clamp(0.0, 1.0),
        'y': (offset.dy / 400.0).clamp(0.0, 1.0),
      });
    }

    if (drawingPoints.isNotEmpty && (drawingPoints.length - 1) % 12 != 0) {
      Offset lastOffset = drawingPoints.last;
      normalizedCoords.add({
        'x': (lastOffset.dx / 300.0).clamp(0.0, 1.0),
        'y': (lastOffset.dy / 400.0).clamp(0.0, 1.0),
      });
    }

    try {
      // 🚀 Dynamic Log Generator for Freestyle canvas runs
      final newMissionRef = FirebaseFirestore.instance
          .collection('robots')
          .doc('LEO_001')
          .collection('missions')
          .doc();

      await FirebaseFirestore.instance
          .collection('robots')
          .doc('LEO_001')
          .update({
            'isCleaning': true,
            'current_action': 'clean_custom_zone',
            'custom_lasso_zone': normalizedCoords,
            'isRobotStuck': false,
            'isDocking': false,
            'isCharging': false,
            'isEmergencyStopped': false,
            'current_active_mission_id': newMissionRef.id,
          });

      await newMissionRef.set({
        'zone': 'Freestyle Zone',
        'type': 'Custom Lasso',
        'timestamp': FieldValue.serverTimestamp(),
        'isSuccess': true,
        'statusMessage': 'Completed Successfully',
        'area': '12 m²',
        'duration': '08 min',
      });

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: const Text(
            'Freestyle Target Synchronized! LEO executing spot clean...',
          ),
          backgroundColor: themeProvider.accentColor,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('🚨 FIRESTORE CRITICAL FAILURE: $e');
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Firebase error: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}
