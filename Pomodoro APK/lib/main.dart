import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'features/pomodoro/presentation/pomodoro_screen.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system navigation and status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final storageService = StorageService(prefs);

  // Request Notification permission for Android 13+ (TIRAMISU / API 33)
  try {
    await Permission.notification.request();
  } catch (_) {}

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storageService),
      ],
      child: const PomodoroApp(),
    ),
  );
}

class PomodoroApp extends ConsumerWidget {
  const PomodoroApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Pomodoro Timer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const PomodoroScreen(),
    );
  }
}
