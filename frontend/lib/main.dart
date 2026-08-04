import 'package:flutter/material.dart';
import 'dart:io';
import 'screens/main_screen.dart';

void main() {
  runApp(const MyApp());
}

// 📌 API Base URL 도우미 (동적 IP / 에뮬레이터 대응)
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