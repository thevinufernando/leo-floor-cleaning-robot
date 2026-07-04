import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class InterfaceCustomizationScreen extends StatelessWidget {
  const InterfaceCustomizationScreen({super.key});

  static const List<Map<String, dynamic>> _accentColors = [
    {'name': 'Cyan Blue', 'color': Color(0xFF35A2FF)},
    {'name': 'Neon Green', 'color': Color(0xFF00E676)},
    {'name': 'Electric Violet', 'color': Color(0xFFD500F9)},
    {'name': 'Amber Alert', 'color': Color(0xFFFFAB00)},
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.scaffoldBg,
      appBar: AppBar(
        backgroundColor: themeProvider.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: themeProvider.textColor,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Interface Customization',
          style: TextStyle(
            color: themeProvider.textColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DISPLAY & THEMING',
                  style: TextStyle(
                    color: themeProvider.accentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Appearance',
                  style: TextStyle(
                    color: themeProvider.textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                // 1. Theme Toggles Group
                _buildSectionHeader('THEME MODES'),
                const SizedBox(height: 8),

                _buildToggleTile(
                  themeProvider: themeProvider,
                  icon: Icons.dark_mode_rounded,
                  title: 'Dark Mode Display',
                  subtitle: 'Optimize UI environment for low-light tracking',
                  value: themeProvider.isDarkMode,
                  onChanged: (val) => themeProvider.toggleDarkMode(val),
                ),

                _buildToggleTile(
                  themeProvider: themeProvider,
                  icon: Icons.contrast_rounded,
                  title: 'High Contrast Mode',
                  subtitle: 'Increase visibility bounds for text readability',
                  value: themeProvider.isHighContrast,
                  onChanged: (val) => themeProvider.toggleHighContrast(val),
                ),

                const SizedBox(height: 24),

                // 2. Layout Accent Color Selector
                _buildSectionHeader('THEME ACCENT COLOR'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: themeProvider.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: themeProvider.isDarkMode
                          ? Colors.white.withOpacity(0.04)
                          : Colors.black.withOpacity(0.05),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Control Center Highlight Color',
                        style: TextStyle(
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.black,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: _accentColors.map((accent) {
                          final Color colorVal = accent['color'] as Color;
                          final bool isSelected =
                              themeProvider.accentColor.value == colorVal.value;
                          return GestureDetector(
                            onTap: () =>
                                themeProvider.updateAccentColor(colorVal),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? (themeProvider.isDarkMode
                                            ? Colors.white
                                            : Colors.black)
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: colorVal,
                                child: isSelected
                                    ? Icon(
                                        Icons.check,
                                        color: themeProvider.scaffoldBg,
                                        size: 16,
                                      )
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Save Configuration Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Preferences saved successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeProvider.accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Save UI Configuration',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF5A6E85),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      ),
    );
  }

  // Helper builder that keeps layout styled exactly like your existing ListTiles
  Widget _buildToggleTile({
    required ThemeProvider themeProvider,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: themeProvider.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: themeProvider.isDarkMode
              ? Colors.white.withOpacity(0.04)
              : Colors.black.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: themeProvider.surfaceBg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: themeProvider.accentColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: themeProvider.textColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: themeProvider.subTextColor,
            fontSize: 11,
            height: 1.3,
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: themeProvider.accentColor,
          activeTrackColor: themeProvider.accentColor.withOpacity(0.2),
          inactiveThumbColor: themeProvider.subTextColor,
          inactiveTrackColor: themeProvider.surfaceBg,
        ),
      ),
    );
  }
}
