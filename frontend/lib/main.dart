import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'subject_provider.dart';
import 'settings_provider.dart'; // 👈 SettingsProvider 추가
import 'screens/main_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SubjectProvider()..fetchSubjects(),
        ),
        ChangeNotifierProvider(
          // 👈 설정 데이터 및 프로필 정보 즉시 로드
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
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8000';
      }
    } catch (_) {
      // Web 및 플랫폼 확인 오류 시 기본 127.0.0.1
    }
    return 'http://127.0.0.1:8000';
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LectureMate MVP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          primary: Colors.indigo,
          secondary: Colors.amber,
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}