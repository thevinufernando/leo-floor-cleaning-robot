import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_provider.dart';

class BiometricAuthScreen extends StatefulWidget {
  const BiometricAuthScreen({super.key});

  @override
  State<BiometricAuthScreen> createState() => _BiometricAuthScreenState();
}

class _BiometricAuthScreenState extends State<BiometricAuthScreen> {
  bool _biometricsEnabled = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _biometricsEnabled = prefs.getBool('biometricsEnabled') ?? false;
    });
  }

  void _handleToggle(bool value) async {
    setState(() {
      _isLoading = true;
    });

    // Simulate link/verification latency
    await Future.delayed(const Duration(milliseconds: 1000));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometricsEnabled', value);

    if (mounted) {
      setState(() {
        _biometricsEnabled = value;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? 'Biometrics Linked Successfully!' : 'Biometrics Disabled.',
          ),
          backgroundColor: value
              ? Provider.of<ThemeProvider>(context, listen: false).accentColor
              : Colors.grey[700],
        ),
      );
    }
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
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: themeProvider.textColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Biometrics',
          style: TextStyle(
            color: themeProvider.textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
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
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.fingerprint_rounded,
                              color: themeProvider.accentColor,
                              size: 24,
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Enable Biometric Login',
                              style: TextStyle(
                                color: themeProvider.textColor,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        _isLoading
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    themeProvider.accentColor,
                                  ),
                                ),
                              )
                            : Switch(
                                value: _biometricsEnabled,
                                activeColor: themeProvider.accentColor,
                                onChanged: _handleToggle,
                              ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Use your device's biometric sensors for quick and secure access.",
                      style: TextStyle(
                        color: themeProvider.subTextColor,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
