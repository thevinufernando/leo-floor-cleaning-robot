import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers to grab text input values
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // State variables to toggle password visibility mask
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      try {
        // 1. Get the currently logged-in user
        User? user = FirebaseAuth.instance.currentUser;

        if (user != null) {
          // 2. Firebase requires re-authenticating the user for security-sensitive actions
          AuthCredential credential = EmailAuthProvider.credential(
            email: user.email!,
            password: _currentPasswordController.text.trim(),
          );

          // Re-authenticate
          await user.reauthenticateWithCredential(credential);

          // 3. Update the password
          await user.updatePassword(_newPasswordController.text.trim());

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          throw FirebaseAuthException(
            code: 'no-user',
            message: 'No active user found. Please log in again.',
          );
        }
      } on FirebaseAuthException catch (e) {
        // Handle errors (e.g., wrong current password, weak password)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'An error occurred. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unexpected error. Please try again later.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

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
          'Change Password',
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
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SECURITY CREDENTIALS',
                    style: TextStyle(
                      color: themeProvider.accentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Update Password',
                    style: TextStyle(
                      color: themeProvider.textColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ensure your account remains secure by using a strong password combining letters, numbers, and symbols.',
                    style: TextStyle(
                      color: themeProvider.subTextColor,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Current Password Field
                  _buildPasswordField(
                    controller: _currentPasswordController,
                    label: 'CURRENT PASSWORD',
                    hint: 'Enter your current password',
                    obscureText: _obscureCurrent,
                    onToggleVisibility: () =>
                        setState(() => _obscureCurrent = !_obscureCurrent),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your current password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // New Password Field
                  _buildPasswordField(
                    controller: _newPasswordController,
                    label: 'NEW PASSWORD',
                    hint: 'Enter your new password',
                    obscureText: _obscureNew,
                    onToggleVisibility: () =>
                        setState(() => _obscureNew = !_obscureNew),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a new password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters long';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Confirm New Password Field
                  _buildPasswordField(
                    controller: _confirmPasswordController,
                    label: 'CONFIRM NEW PASSWORD',
                    hint: 'Retype your new password',
                    obscureText: _obscureConfirm,
                    onToggleVisibility: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    validator: (value) {
                      if (value != _newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 40),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeProvider.accentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Save New Password',
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
      ),
    );
  }

  // Custom Input Field Helper mimicking your design language
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    required String? Function(String?) validator,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: themeProvider.subTextColor,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: themeProvider.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            style: TextStyle(color: themeProvider.textColor, fontSize: 14),
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: isDark ? const Color(0xFF3A4D60) : Colors.grey[500],
                fontSize: 14,
              ),
              filled: true,
              fillColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: InputBorder.none,
              suffixIcon: IconButton(
                icon: Icon(
                  obscureText
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: themeProvider.subTextColor,
                  size: 20,
                ),
                onPressed: onToggleVisibility,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
