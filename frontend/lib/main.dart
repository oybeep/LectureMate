import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'subject_provider.dart';
import 'settings_provider.dart';
import 'screens/main_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SubjectProvider()..fetchSubjects(),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider()..fetchInitialData(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class ApiConfig {
  static String get baseUrl {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        return 'http://10.0.2.2:8000';
      }
    } catch (_) {
      // Web 및 플랫폼 확인 오류 시 기본값 적용
    }
    return 'http://127.0.0.1:8000';
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // SettingsProvider 상태 감시
    final settingsProvider = context.watch<SettingsProvider>();
    final isDarkMode = settingsProvider.appSettings?.isDarkMode ?? false;

    return MaterialApp(
      title: 'LectureMate MVP',
      debugShowCheckedModeBanner: false,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,

      // ☀️ 라이트 테마
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          primary: Colors.indigo,
          secondary: Colors.amber,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),

      // 🌙 다크 테마 (보완된 세련된 딥그레이 톤)
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212), // 눈이 편안한 딥 차콜
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
          surface: const Color(0xFF1E1E1E), // 카드 및 대화상자 배경색
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1F1F1F),
          elevation: 0,
        ),
      ),

      home: const MainScreen(),
    );
  }
}