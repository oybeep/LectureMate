import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart'; // 👈 Provider 패키지 임포트
import 'subject_provider.dart'; // 👈 방금 작성한 SubjectProvider 파일 경로
import 'screens/main_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          // 앱 실행 시 과목 및 시간표 데이터를 즉시 로드합니다.
          create: (_) => SubjectProvider()..fetchSubjects(),
        ),
      ],
      child: const MyApp(),
    ),
  );
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