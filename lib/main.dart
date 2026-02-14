import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/participant_provider.dart';
import 'providers/supervisor_provider.dart';
import 'providers/monitor_provider.dart';
import 'providers/offline_database_provider.dart';
import 'providers/unsent_data_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/font_provider.dart';
import 'design/app_theme.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => FontProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ParticipantProvider()),
        ChangeNotifierProvider(create: (_) => SupervisorProvider()),
        ChangeNotifierProvider(create: (_) => MonitorProvider()),
        ChangeNotifierProvider(create: (_) => OfflineDatabaseProvider()),
        ChangeNotifierProvider(create: (_) => UnsentDataProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'DİM Buraxılış Sistemi',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.flutterThemeMode,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
