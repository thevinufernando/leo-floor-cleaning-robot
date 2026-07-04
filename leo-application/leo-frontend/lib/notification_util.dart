import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class NotificationUtil {
  /// Displays a clean, Android Material 3 styled heads-up notification banner
  static void showAndroidNotification(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top:
            MediaQuery.of(context).padding.top +
            12, // Standard Android status bar clearance
        left: 12,
        right: 12,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve:
                Curves.easeOutCubic, // Clean Android linear-out-slow-in easing
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, (1 - value) * -80),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(
                  0xFF232E3A,
                ), // Dark solid slate matching Android Material 3 dark surfaces
                borderRadius: BorderRadius.circular(
                  28,
                ), // Signature M3 ultra-rounded corner geometry
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Android App Icon Identifier
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: themeProvider.scaffoldBg,
                    ),
                    child: Icon(
                      Icons
                          .smart_toy_rounded, // Cool generic Android robot/bot asset profile symbol
                      color: themeProvider.accentColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Text Payload Block
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          message,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Inject into the application render layer stack
    Overlay.of(context).insert(overlayEntry);

    // Auto disappear after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }
}
