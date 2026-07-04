import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class TermsPrivacyScreen extends StatelessWidget {
  const TermsPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

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
          'Terms & Privacy',
          style: TextStyle(
            color: themeProvider.textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(
                title: '1. Acceptance of Terms',
                body:
                    'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.',
                themeProvider: themeProvider,
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: '2. Data Privacy & Security',
                body:
                    'Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Curabitur pretium tincidunt lacus. Nulla gravida orci a odio. Nullam varius, turpis et commodo pharetra, est eros bibendum elit, nec luctus magna felis sollicitudin mauris. Integer in mauris eu nibh euismod gravida. Duis ac tellus.',
                themeProvider: themeProvider,
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: '3. Robot Operational Guidelines',
                body:
                    'Fusce id velit ut tortor pretium viverra. Suspendisse potenti nullam ac tortor vitae purus faucibus ornare. Eget sit amet tellus cras adipiscing enim. Egestas egestas fringilla phasellus faucibus scelerisque eleifend. Consequat nisl vel pretium lectus quam id leo in vitae. Arcu dictum varius duis at consectetur lorem donec massa.',
                themeProvider: themeProvider,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String body,
    required ThemeProvider themeProvider,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: themeProvider.accentColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          body,
          style: TextStyle(
            color: themeProvider.textColor,
            fontSize: 12,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}
