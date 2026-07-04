import 'package:first_app_test/map_screen.dart';
import 'package:flutter/material.dart';
import 'simulation_service.dart';
import 'notification_util.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:first_app_test/schedule_screen.dart';
import 'package:first_app_test/history_screen.dart';
import 'package:first_app_test/settings_screen.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  bool isCleaning = false;
  int batteryLevel = 16;
  String currentMode = 'Auto Mode';
  bool isEmergencyStopped = false;
  bool isDocking = false;
  bool isCharging = false;
  bool isVerifyingFault = false;
  bool isRobotStuck = false;
  final SimulationService _simulationService = SimulationService();
  String lastCleanedTime = '4 hours ago';
  bool isOnline = true;

  // ⏱️ App-Side Clock State Tracker
  DateTime? _missionStartTime;

  final List<String> _screenTitles = [
    'Home Screen',
    'Map Screen',
    'Schedule Screen',
    'History Screen',
    'Settings Screen',
  ];

  final List<IconData> _screenIcons = [
    Icons.home_rounded,
    Icons.map_rounded,
    Icons.calendar_month_rounded,
    Icons.history_rounded,
    Icons.settings_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('robots')
          .doc('LEO_001')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          final robotDoc = snapshot.data!;
          final robotData = robotDoc.data() as Map<String, dynamic>;

          batteryLevel =
              (robotDoc['batteryLevel'] as num?)?.toInt() ?? batteryLevel;
          isCleaning = robotDoc['isCleaning'] ?? isCleaning;
          isCharging = robotDoc['isCharging'] ?? isCharging;
          isEmergencyStopped =
              robotDoc['isEmergencyStopped'] ?? isEmergencyStopped;
          currentMode = robotDoc['currentMode'] ?? currentMode;
          lastCleanedTime = robotDoc['lastCleanedTime'] ?? lastCleanedTime;
          isRobotStuck = robotDoc['isRobotStuck'] ?? isRobotStuck;
          isVerifyingFault = robotDoc['isVerifyingFault'] ?? isVerifyingFault;

          final Timestamp? lastSeenTimestamp =
              robotData['lastSeen'] as Timestamp?;
          if (lastSeenTimestamp != null) {
            final difference = DateTime.now().difference(
              lastSeenTimestamp.toDate(),
            );
            isOnline = difference.inSeconds < 15;
          } else {
            isOnline = false;
          }
        }

        final themeProvider = Provider.of<ThemeProvider>(context);
        final isDark = themeProvider.isDarkMode;
        final backgroundColor = isDark
            ? const Color(0xFF070D14)
            : Colors.grey[100]!;

        return Scaffold(
          backgroundColor: backgroundColor,
          body: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF0A1118), const Color(0xFF050A0E)]
                      : [Colors.grey[100]!, Colors.grey[200]!],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    if (_currentIndex == 0) _buildAppBar(),

                    Expanded(
                      child: _currentIndex == 2
                          ? const ScheduleScreen()
                          : _currentIndex == 3
                          ? const HistoryScreen()
                          : _currentIndex == 4
                          ? const SettingsScreen()
                          : SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Center(child: _buildPlaceholderContent()),
                            ),
                    ),

                    _buildBottomNavigationBar(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final textColor = themeProvider.textColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3A4D60), Color(0xFF1E2833)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.person_rounded,
                    color: Colors.white70,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getTimeBasedGreeting(),
                    style: TextStyle(
                      color: themeProvider.accentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'LEO',
                    style: TextStyle(
                      color: themeProvider.accentColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderContent() {
    if (_currentIndex == 0) return _buildHomeContent();
    if (_currentIndex == 1) return const MapScreen();

    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final cardColor = themeProvider.cardBg;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141A1F) : Colors.grey[200]!,
              shape: BoxShape.circle,
              border: Border.all(
                color: themeProvider.accentColor.withOpacity(0.15),
                width: 1.5,
              ),
            ),
            child: Icon(
              _screenIcons[_currentIndex],
              size: 48,
              color: themeProvider.accentColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _screenTitles[_currentIndex],
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'This is a placeholder for the ${_screenTitles[_currentIndex].toLowerCase()}.\nMain interface components will be integrated here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: subTextColor, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHomeCard(),
        _buildSystemLogSection(),
        _buildQuickActions(),
      ],
    );
  }

  Widget _buildQuickActions() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final textColor = themeProvider.textColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Text(
            'Quick Actions',
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              WidgetActionButtonWrapper(
                isCleaning: isCleaning,
                isVerifyingFault: isVerifyingFault,
                formatCurrentTime: _formatCurrentTime,
                simulationService: _simulationService,
                missionStartTime: _missionStartTime,
                onResetClock: () => setState(() {
                  _missionStartTime = null;
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildHomeCard() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = themeProvider.textColor;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (isDark ? const Color(0xFF162534) : Colors.grey[200]!).withOpacity(
              0.95,
            ),
            (isDark ? const Color(0xFF0D161F) : Colors.grey[100]!).withOpacity(
              0.95,
            ),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.06),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: isCleaning
                ? themeProvider.accentColor.withOpacity(0.08)
                : Colors.transparent,
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF122232),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCharging
                        ? Colors.greenAccent
                        : (isCleaning
                              ? themeProvider.accentColor
                              : Colors.blueGrey),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'STATUS',
                  style: TextStyle(
                    color: themeProvider.accentColor.withOpacity(0.8),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isCharging
                ? 'Charging & Connected'
                : (isDocking
                      ? 'Returning to Dock...'
                      : (isVerifyingFault
                            ? "Verifying Subsystems..."
                            : (isEmergencyStopped
                                  ? "Emergency Stop"
                                  : (isRobotStuck
                                        ? "Robot Blocked"
                                        : (batteryLevel <= 15
                                              ? "Battery Critically Low"
                                              : (isCleaning
                                                    ? "Cleaning..."
                                                    : 'Ready to Clean')))))),
            style: TextStyle(
              color: isCharging
                  ? Colors.greenAccent
                  : (isDocking
                        ? Colors.orangeAccent
                        : (isEmergencyStopped ||
                                  isVerifyingFault ||
                                  isRobotStuck ||
                                  batteryLevel <= 15
                              ? Colors.redAccent
                              : textColor)),
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          if (isRobotStuck ||
              (!isCleaning && !isVerifyingFault && !isCharging && !isDocking))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                isRobotStuck
                    ? 'Operation paused due to an obstruction'
                    : 'Last cleaned $lastCleanedTime',
                style: const TextStyle(
                  color: Color(0xFF6B7C8E),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    _buildMiniWidgetBadge(
                      icon: isCharging
                          ? Icons.battery_charging_full_rounded
                          : Icons.battery_std_rounded,
                      title: 'Battery',
                      value: '$batteryLevel%',
                      color: isCharging
                          ? Colors.greenAccent
                          : themeProvider.accentColor,
                    ),
                    const SizedBox(height: 16),
                    PopupMenuButton<String>(
                      onSelected: isVerifyingFault
                          ? null
                          : (String newMode) async {
                              await FirebaseFirestore.instance
                                  .collection('robots')
                                  .doc('LEO_001')
                                  .update({'currentMode': newMode});
                            },
                      tooltip: 'Select Mode',
                      offset: const Offset(0, 50),
                      color: const Color(0xFF1E2730),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: Colors.white.withOpacity(0.05),
                          width: 1,
                        ),
                      ),
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'Auto Mode',
                              child: Text(
                                'Auto Mode',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'Eco Mode',
                              child: Text(
                                'Eco Mode',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'Max Suction',
                              child: Text(
                                'Max Suction',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                      child: _buildMiniWidgetBadge(
                        icon: Icons.sync_rounded,
                        title: 'Mode',
                        value: currentMode,
                        color: isVerifyingFault
                            ? Colors.grey
                            : themeProvider.accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 5,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: isDark
                          ? [const Color(0xFF162535), const Color(0xFF070D14)]
                          : [Colors.grey[200]!, Colors.grey[100]!],
                      center: Alignment.center,
                      radius: 0.8,
                    ),
                    border: Border.all(
                      color: isCleaning
                          ? themeProvider.accentColor.withOpacity(0.6)
                          : themeProvider.accentColor.withOpacity(0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isCleaning
                            ? themeProvider.accentColor.withOpacity(0.25)
                            : themeProvider.accentColor.withOpacity(0.03),
                        blurRadius: 20,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isVerifyingFault
                              ? Icons.hourglass_empty_rounded
                              : Icons.blur_circular_rounded,
                          color: isVerifyingFault
                              ? Colors.amberAccent
                              : (isCleaning
                                    ? themeProvider.accentColor
                                    : Colors.white24),
                          size: 40,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isVerifyingFault
                              ? 'PINGING BUS...'
                              : (isCleaning ? 'ROBOT ACTIVE' : 'LEO IDLE'),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: isVerifyingFault
                    ? [const Color(0xFFF1C40F), const Color(0xFFD4AC0D)]
                    : (batteryLevel <= 15 && !isCharging
                          ? [const Color(0xFFF39C12), const Color(0xFFD35400)]
                          : [
                              themeProvider.accentColor,
                              themeProvider.accentColor.withValues(alpha: 0.8),
                            ]),
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              boxShadow: [
                BoxShadow(
                  color: isVerifyingFault
                      ? const Color(0xFFFF9100).withOpacity(0.3)
                      : themeProvider.accentColor.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: isVerifyingFault
                    ? null
                    : () async {
                        final docRef = FirebaseFirestore.instance
                            .collection('robots')
                            .doc('LEO_001');

                        if (batteryLevel <= 15 && !isCharging) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(
                                    Icons.power_rounded,
                                    color: themeProvider.accentColor,
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      "Please physically connect LEO's 12V charging adapter. The dashboard will automatically update once connected.",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: themeProvider.isDarkMode
                                  ? const Color(0xFF14202C)
                                  : Colors.grey[900],
                              duration: const Duration(seconds: 6),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                          return;
                        }

                        if (isEmergencyStopped) {
                          await docRef.update({'isVerifyingFault': true});
                          return;
                        }

                        if (isCharging) {
                          await docRef.update({
                            'isCharging': false,
                            'isCleaning': false,
                            'isRobotStuck': false,
                            'isEmergencyStopped': false,
                          });
                          NotificationUtil.showAndroidNotification(
                            context,
                            title: 'LEO Power Monitor',
                            message:
                                'Charger Disconnected: LEO is now on battery power and ready to clean.',
                          );
                          return;
                        }

                        bool targetCleaningState = !isCleaning;
                        if (!targetCleaningState) {
                          final robotDoc = await FirebaseFirestore.instance
                              .collection('robots')
                              .doc('LEO_001')
                              .get();
                          final robotData =
                              robotDoc.data() as Map<String, dynamic>;
                          final String? activeMissionId =
                              robotData['current_active_mission_id'];

                          int elapsedSeconds = 5;
                          if (_missionStartTime != null) {
                            elapsedSeconds = DateTime.now()
                                .difference(_missionStartTime!)
                                .inSeconds;
                          }
                          double calculatedArea = elapsedSeconds * 0.4;

                          if (activeMissionId != null) {
                            await FirebaseFirestore.instance
                                .collection('robots')
                                .doc('LEO_001')
                                .collection('missions')
                                .doc(activeMissionId)
                                .update({
                                  'duration': elapsedSeconds < 60
                                      ? '$elapsedSeconds sec'
                                      : '${(elapsedSeconds / 60).floor()} min',
                                  'area':
                                      '${calculatedArea.toStringAsFixed(1)} m²',
                                  'statusMessage': 'Completed Successfully',
                                });
                          }

                          setState(() {
                            _missionStartTime = null;
                          });

                          await docRef.update({
                            'isCleaning': false,
                            'desired_state.isCleaning': false,
                            'isRobotStuck': false,
                            'isDocking': false,
                            'isCharging': false,
                            'lastCleanedTime': _formatCurrentTime(),
                          });
                        } else {
                          final newMissionRef = FirebaseFirestore.instance
                              .collection('robots')
                              .doc('LEO_001')
                              .collection('missions')
                              .doc();
                          setState(() {
                            _missionStartTime = DateTime.now();
                          });

                          await docRef.update({
                            'isCleaning': true,
                            'desired_state.isCleaning': true,
                            'isRobotStuck': false,
                            'isDocking': false,
                            'isCharging': false,
                            'current_active_mission_id': newMissionRef.id,
                          });

                          await newMissionRef.set({
                            'zone': 'Full House',
                            'type': 'Manual Run',
                            'timestamp': FieldValue.serverTimestamp(),
                            'isSuccess': true,
                            'statusMessage': 'Running...',
                            'area': '0 m²',
                            'duration': '0 min',
                          });
                        }
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isVerifyingFault
                                ? Icons.sync
                                : (isCharging
                                      ? Icons.battery_charging_full_rounded
                                      : (batteryLevel <= 15
                                            ? Icons.power_rounded
                                            : (isCleaning
                                                  ? Icons
                                                        .pause_circle_filled_rounded
                                                  : Icons
                                                        .play_circle_filled_rounded))),
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            isVerifyingFault
                                ? 'Waiting for LEO to confirm...'
                                : (isEmergencyStopped
                                      ? 'Reset System Fault'
                                      : (isCharging
                                            ? 'Charging Subsystems...'
                                            : (batteryLevel <= 15
                                                  ? 'Connect Charging Cable'
                                                  : (isCleaning
                                                        ? 'Pause Execution'
                                                        : 'Start Cleaning')))),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        isVerifyingFault
                            ? Icons.sync
                            : (isEmergencyStopped
                                  ? Icons.refresh_rounded
                                  : Icons.arrow_forward_ios_rounded),
                        color: Colors.white54,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemLogSection() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    String logTitle = 'ALL GOOD!';
    String logDescription =
        'LEO is on track and everything is running smoothly';
    Color stateColor = Colors.greenAccent;
    IconData logIcon = Icons.check_circle_outline_rounded;

    if (isCharging) {
      logTitle = 'POWERING UP';
      logDescription = 'LEO is resting and recharging';
      stateColor = Colors.greenAccent;
      logIcon = Icons.bolt_rounded;
    } else if (batteryLevel <= 15 && !isCharging) {
      logTitle = 'NEED CHARGE!!';
      logDescription =
          'LEO is out of energy (15%). Please connect his charging cable to help him out';
      stateColor = Colors.orangeAccent;
      logIcon = Icons.battery_alert_rounded;
    } else if (isVerifyingFault) {
      logTitle = 'GETTING THINGS READY';
      logDescription = 'LEO is making sure all systems are good to go';
      stateColor = Colors.amberAccent;
      logIcon = Icons.sync_rounded;
    } else if (isEmergencyStopped) {
      logTitle = 'SAFELY PAUSED';
      logDescription =
          'LEO needs a quick safety check before he can continue cleaning';
      stateColor = Colors.redAccent;
      logIcon = Icons.gavel_rounded;
    } else if (isRobotStuck) {
      logTitle = 'OOPS! SOMETHING IS WRONG';
      logDescription = 'LEO needs a little help. Please check on him';
      stateColor = Colors.orangeAccent;
      logIcon = Icons.warning_amber_rounded;
    } else if (isCleaning) {
      logTitle = 'TIME TO CLEAN!!';
      logDescription = 'LEO is working hard. Do not disturb him';
      stateColor = themeProvider.accentColor;
      logIcon = Icons.blur_circular_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF16222F).withOpacity(0.7),
              const Color(0xFF0F1822).withOpacity(0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: stateColor.withOpacity(0.2), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'SYSTEM DIAGNOSTIC TOOL',
                  style: TextStyle(
                    color: Color(0xFF5A6E85),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: stateColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(logIcon, color: stateColor, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        logTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        logDescription,
                        style: const TextStyle(
                          color: Color(0xFF6B7C8E),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniWidgetBadge({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? const Color(0xFF0C1620) : Colors.grey[200]!,
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: themeProvider.subTextColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: themeProvider.textColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF14202E).withOpacity(0.85),
            const Color(0xFF091017).withOpacity(0.95),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.06), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, 'Home', Icons.home_outlined, Icons.home_rounded),
          _buildNavItem(1, 'Map', Icons.map_outlined, Icons.map_rounded),
          _buildNavItem(
            2,
            'Schedule',
            Icons.calendar_month_outlined,
            Icons.calendar_month_rounded,
          ),
          _buildNavItem(
            3,
            'History',
            Icons.history_rounded,
            Icons.history_rounded,
          ),
          _buildNavItem(
            4,
            'Settings',
            Icons.settings_outlined,
            Icons.settings_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    String label,
    IconData inactiveIcon,
    IconData activeIcon,
  ) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isSelected = _currentIndex == index;
    final Color itemColor = isSelected
        ? themeProvider.accentColor
        : themeProvider.subTextColor;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? activeIcon : inactiveIcon,
                color: itemColor,
                size: 24,
                shadows: isSelected
                    ? [
                        Shadow(
                          color: themeProvider.accentColor.withOpacity(0.4),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  color: itemColor,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 12,
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: isSelected
                      ? themeProvider.accentColor
                      : Colors.transparent,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: themeProvider.accentColor.withOpacity(0.5),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTimeBasedGreeting() {
    final int hour = DateTime.now().hour;
    if (hour < 12) return 'GOOD MORNING';
    if (hour < 17) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }

  String _formatCurrentTime() {
    final DateTime now = DateTime.now();
    int hour = now.hour % 12;
    if (hour == 0) hour = 12;
    final String minute = now.minute < 10 ? '0${now.minute}' : '${now.minute}';
    final String amPm = now.hour >= 12 ? 'PM' : 'AM';
    return 'at $hour:$minute $amPm';
  }
}

class WidgetActionButtonWrapper extends StatelessWidget {
  final bool isCleaning;
  final bool isVerifyingFault;
  final String Function() formatCurrentTime;
  final SimulationService simulationService;
  final DateTime? missionStartTime;
  final VoidCallback onResetClock;

  const WidgetActionButtonWrapper({
    super.key,
    required this.isCleaning,
    required this.isVerifyingFault,
    required this.formatCurrentTime,
    required this.simulationService,
    required this.missionStartTime,
    required this.onResetClock,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 90,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (isDark ? const Color(0xFF16222F) : Colors.grey[200]!)
                      .withOpacity(0.8),
                  (isDark ? const Color(0xFF0F1822) : Colors.grey[100]!)
                      .withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.05),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  if (isVerifyingFault) return;

                  if (isCleaning) {
                    final robotDoc = await FirebaseFirestore.instance
                        .collection('robots')
                        .doc('LEO_001')
                        .get();
                    final robotData = robotDoc.data() as Map<String, dynamic>;
                    final String? activeMissionId =
                        robotData['current_active_mission_id'];

                    int elapsedSeconds = 4;
                    if (missionStartTime != null) {
                      elapsedSeconds = DateTime.now()
                          .difference(missionStartTime!)
                          .inSeconds;
                    }
                    double calculatedArea = elapsedSeconds * 0.4;

                    if (activeMissionId != null) {
                      await FirebaseFirestore.instance
                          .collection('robots')
                          .doc('LEO_001')
                          .collection('missions')
                          .doc(activeMissionId)
                          .update({
                            'isSuccess': false,
                            'statusMessage': 'Aborted • Emergency Stop',
                            'duration': '$elapsedSeconds sec',
                            'area': '${calculatedArea.toStringAsFixed(1)} m²',
                          });
                    }

                    onResetClock();

                    await FirebaseFirestore.instance
                        .collection('robots')
                        .doc('LEO_001')
                        .update({
                          'isCleaning': false,
                          'desired_state.isCleaning': false,
                          'isEmergencyStopped': true,
                          'lastCleanedTime': formatCurrentTime(),
                        });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('EMERGENCY STOP ENFORCED: Motors cut.'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(24),
                child: Center(
                  child: Icon(
                    Icons.pause_rounded,
                    color: isCleaning ? Colors.redAccent : Colors.grey,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Emergency Pause',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: themeProvider.textColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
