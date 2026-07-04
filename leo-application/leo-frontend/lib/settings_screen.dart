import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'interface_customization_screen.dart';
import 'change_password_screen.dart';
import 'biometric_auth_screen.dart';
import 'notification_controls_screen.dart';
import 'terms_privacy_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Listen to the global theme changes dynamically
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? user?.email ?? 'Janani Hendeniya';
    final userRole = user != null ? 'Operator Account • Active' : 'Offline Guest Mode';

    // Dynamic background and card container colors based on theme mode
    final backgroundColor = themeProvider.scaffoldBg;
    final cardColor = themeProvider.cardBg;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header Group
                Text(
                  'APPLICATION INTERFACE',
                  style: TextStyle(
                    color:
                        themeProvider.accentColor, // Uses Dynamic Accent Color
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'User Settings',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 28),

                // 2. Profile Summary Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.04),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF3A4D60), Color(0xFF1E2833)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            userRole,
                            style: TextStyle(
                              color: subTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // 3. Category: Account & Security
                _buildSectionHeader('ACCOUNT SECURITY'),
                const SizedBox(height: 8),
                _buildSettingTile(
                  context: context,
                  icon: Icons.lock_outline_rounded,
                  title: 'Change Password',
                  subtitle: 'Update your login credentials securely',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChangePasswordScreen(),
                      ),
                    );
                  },
                ),
                _buildSettingTile(
                  context: context,
                  icon: Icons.fingerprint_rounded,
                  title: 'Biometric Authentication',
                  subtitle: 'Manage fingerprint and face lock access',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BiometricAuthScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // 4. Category: App Preferences
                _buildSectionHeader('PREFERENCES'),
                const SizedBox(height: 8),
                _buildSettingTile(
                  context: context,
                  icon: Icons.notifications_none_rounded,
                  title: 'Notification Controls',
                  subtitle: 'Configure critical fault alert sound mappings',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationControlsScreen(),
                      ),
                    );
                  },
                ),
                _buildSettingTile(
                  context: context,
                  icon: Icons.palette_outlined,
                  title: 'Interface Customization',
                  subtitle: 'Toggle dark mode options or theme accents',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const InterfaceCustomizationScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // 5. Category: Legal & Support
                _buildSectionHeader('SYSTEM INFORMATION'),
                const SizedBox(height: 8),
                _buildSettingTile(
                  context: context,
                  icon: Icons.description_outlined,
                  title: 'Terms of Service & Privacy',
                  subtitle: 'Review legal user agreements and guidelines',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TermsPrivacyScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // App Version Tag
                Center(
                  child: Text(
                    'LEO Control Center • Version 1.0.2',
                    style: TextStyle(
                      color: subTextColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
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

  Widget _buildSettingTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    final cardColor = themeProvider.cardBg;
    final tileBg = themeProvider.surfaceBg;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        type: MaterialType.transparency,
        child: ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: tileBg, shape: BoxShape.circle),
            child: Icon(icon, color: themeProvider.accentColor, size: 20),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(color: subTextColor, fontSize: 11, height: 1.3),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios_rounded,
            color: themeProvider.isDarkMode ? Colors.white24 : Colors.black26,
            size: 12,
          ),
        ),
      ),
    );
  }
}
