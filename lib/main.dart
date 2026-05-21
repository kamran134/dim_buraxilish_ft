import 'package:firebase_core/firebase_core.dart';
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
import 'providers/notifications_provider.dart';
import 'services/sync_service.dart';
import 'services/emergency_message_service.dart';
import 'services/push_notification_service.dart';
import 'design/app_theme.dart';
import 'screens/splash_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  EmergencyMessageService.instance.init(navigatorKey);
  PushNotificationService.instance.init();
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
        // SyncService singleton exposed as a ChangeNotifier so widgets can
        // listen to pendingCount / isSyncing without manual subscriptions.
        ChangeNotifierProvider.value(value: SyncService.instance),
        ChangeNotifierProvider.value(value: NotificationsProvider.instance),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'DİM Buraxılış Sistemi',
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
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
