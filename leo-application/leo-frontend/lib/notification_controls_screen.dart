import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationControlsScreen extends StatefulWidget {
  const NotificationControlsScreen({super.key});

  @override
  State<NotificationControlsScreen> createState() => _NotificationControlsScreenState();
}

class _NotificationControlsScreenState extends State<NotificationControlsScreen> {
  bool _criticalAlerts = true;
  bool _statusUpdates = true;
  bool _pushNotifications = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _criticalAlerts = prefs.getBool('criticalAlerts') ?? true;
      _statusUpdates = prefs.getBool('statusUpdates') ?? true;
      _pushNotifications = prefs.getBool('pushNotifications') ?? false;
    });
  }

  Future<void> _updatePref(String key, bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, val);
  }

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
          icon: Icon(Icons.arrow_back_ios_rounded, color: themeProvider.textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(
            color: themeProvider.textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            _buildToggleItem(
              title: 'Critical Fault Alerts',
              description: 'Sound mappings for high-priority hardware alerts',
              value: _criticalAlerts,
              onChanged: (val) {
                setState(() => _criticalAlerts = val);
                _updatePref('criticalAlerts', val);
              },
              themeProvider: themeProvider,
              isDark: isDark,
            ),
            _buildToggleItem(
              title: 'Status Updates',
              description: 'Get notified when tasks or schedules finish',
              value: _statusUpdates,
              onChanged: (val) {
                setState(() => _statusUpdates = val);
                _updatePref('statusUpdates', val);
              },
              themeProvider: themeProvider,
              isDark: isDark,
            ),
            _buildToggleItem(
              title: 'Push Notifications',
              description: 'General app notifications',
              value: _pushNotifications,
              onChanged: (val) {
                setState(() => _pushNotifications = val);
                _updatePref('pushNotifications', val);
              },
              themeProvider: themeProvider,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleItem({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
    required ThemeProvider themeProvider,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: themeProvider.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.04)
              : Colors.black.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: themeProvider.textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: themeProvider.subTextColor,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: value,
            activeColor: themeProvider.accentColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
