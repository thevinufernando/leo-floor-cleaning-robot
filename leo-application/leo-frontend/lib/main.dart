import 'package:firebase_core/firebase_core.dart'; // 🔌 Import 1: Core Engine
import 'firebase_options.dart';

import 'home_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

// 1. Change to "async" so your app can wait for the network to boot up
void main() async {
  // 2. These two lines establish the handshake line to your online console
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Leo Robot Vacuum',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: themeProvider.isDarkMode
            ? Brightness.dark
            : Brightness.light,
        scaffoldBackgroundColor: themeProvider.isDarkMode
            ? const Color(0xFF141A1F)
            : const Color(0xFFF5F7FA),
        primaryColor: themeProvider.accentColor,
        colorScheme: themeProvider.isDarkMode
            ? ColorScheme.dark(
                primary: themeProvider.accentColor,
                surface: const Color(0xFF1A2229),
              )
            : ColorScheme.light(
                primary: themeProvider.accentColor,
                surface: Colors.white,
              ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}
