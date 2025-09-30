import 'package:flutter/material.dart';
import 'design/app_colors.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/participant_provider.dart';
import 'providers/supervisor_provider.dart';
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
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ParticipantProvider()),
        ChangeNotifierProvider(create: (_) => SupervisorProvider()),
      ],
      child: MaterialApp(
        title: 'DİM Buraxılış Sistemi',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.deepBlue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          fontFamily: 'System',
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.deepBlue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          fontFamily: 'System',
        ),
        themeMode: ThemeMode.system, // Follows system theme
        home: const SplashScreen(),
      ),
    );
  }
}
