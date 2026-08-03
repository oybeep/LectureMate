import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LectureMate',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _healthStatus = '서버 연결 확인 중...';
  List<dynamic> _subjects = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // 백엔드 API 연동 함수
  Future<void> _fetchData() async {
    try {
      // 1. Health check 호출 (Android 에뮬레이터 기준 10.0.2.2, Chrome/Web은 localhost)
      final healthRes = await http.get(Uri.parse('http://127.0.0.1:8000/health'));
      if (healthRes.statusCode == 200) {
        final healthData = jsonDecode(healthRes.body);
        setState(() {
          _healthStatus = healthData['message'];
        });
      }

      // 2. 과목 목록 조회
      final subjectsRes = await http.get(Uri.parse('http://127.0.0.1:8000/subjects'));
      if (subjectsRes.statusCode == 200) {
        final subjectsData = jsonDecode(subjectsRes.body);
        setState(() {
          _subjects = subjectsData;
        });
      }
    } catch (e) {
      setState(() {
        _healthStatus = '서버 연결 실패: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LectureMate - 강의 요약 에이전트'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 서버 상태 카드
            Card(
              child: ListTile(
                leading: const Icon(Icons.dns, color: Colors.green),
                title: const Text('서버 상태'),
                subtitle: Text(_healthStatus),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '내 수강 과목 목록',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            // 백엔드에서 받아온 과목 리스트 표시
            Expanded(
              child: _subjects.isEmpty
                  ? const Center(child: Text('등록된 과목이 없습니다.'))
                  : ListView.builder(
                      itemCount: _subjects.length,
                      itemBuilder: (context, index) {
                        final subject = _subjects[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.book),
                            title: Text(subject['title'] ?? ''),
                            subtitle: Text(
                              '${subject['instructor'] ?? ''} | ${subject['time_slot'] ?? ''}',
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}