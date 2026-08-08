import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart'; // ApiConfig 참조

class SubjectProvider extends ChangeNotifier {
  List<dynamic> _subjects = [];
  Map<String, List<Map<String, String>>> _timetable = {
    '월': [], '화': [], '수': [], '목': [], '금': [],
  };

  List<dynamic> get subjects => _subjects;
  Map<String, List<Map<String, String>>> get timetable => _timetable;

  // 서버에서 과목 목록 불러오기
  Future<void> fetchSubjects() async {
    try {
      final baseUrl = ApiConfig.baseUrl;
      final response = await http.get(Uri.parse('$baseUrl/subjects/'));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        _subjects = data;
        
        // 시간표 데이터 재구성
        _buildTimetable();
        notifyListeners(); // 👈 UI 실시간 반영
      }
    } catch (e) {
      debugPrint('과목 로드 오류: $e');
    }
  }

  // 과목 추가
  Future<bool> addSubject(String title, String professor, String timeSlot) async {
    try {
      final baseUrl = ApiConfig.baseUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/subjects/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': title,
          'professor': professor,
          'time_slot': timeSlot,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchSubjects();
        return true; // 👈 성공 시 true 반환
      }
      return false;
    } catch (e) {
      debugPrint('과목 추가 오류: $e');
      return false; // 👈 실패 시 false 반환
    }
  }

// 과목 수정
  Future<bool> updateSubject(int id, String title, String professor, String timeSlot) async {
    try {
      final baseUrl = ApiConfig.baseUrl;
      final response = await http.put(
        Uri.parse('$baseUrl/subjects/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': title,
          'professor': professor,
          'time_slot': timeSlot,
        }),
      );

      if (response.statusCode == 200) {
        await fetchSubjects();
        return true; // 👈 성공 시 true 반환
      }
      return false;
    } catch (e) {
      debugPrint('과목 수정 오류: $e');
      return false; // 👈 실패 시 false 반환
    }
  }

  // 과목 삭제
  Future<bool> deleteSubject(int id) async {
    try {
      final baseUrl = ApiConfig.baseUrl;
      final response = await http.delete(Uri.parse('$baseUrl/subjects/$id'));

      if (response.statusCode == 200) {
        await fetchSubjects();
        return true; // 👈 성공 시 true 반환
      }
      return false;
    } catch (e) {
      debugPrint('과목 삭제 오류: $e');
      return false; // 👈 실패 시 false 반환
    }
  }

  // 과목 리스트를 기반으로 Timetable 맵을 생성하는 메서드
  void _buildTimetable() {
    final Map<String, List<Map<String, String>>> newTimetable = {
      '월': [], '화': [], '수': [], '목': [], '금': [],
    };

    final List<String> days = ['월', '화', '수', '목', '금'];

    for (var sub in _subjects) {
      final String title = sub['title'] ?? sub['name'] ?? '미정';
      final String instructor = sub['professor'] ?? sub['instructor'] ?? sub['professor_name'] ?? '미지정';
      
      // time_slot, time, time_info 등 모든 키 이름에 대응
      final String timeSlot = (sub['time_slot'] ?? sub['time'] ?? sub['time_info'] ?? '').toString().trim();

      if (timeSlot.isEmpty) continue;

      String foundDay = '';
      for (String d in days) {
        if (timeSlot.contains(d)) {
          foundDay = d;
          break;
        }
      }

      if (foundDay.isNotEmpty) {
        // "월 09:00~10:30" 또는 "월 09:00 ~ 10:30" 등 파싱
        String timeOnly = timeSlot.replaceAll(foundDay, '').trim();
        List<String> timeParts = timeOnly.split('~');

        String startTime = '09:00';
        String endTime = '10:30';

        if (timeParts.length >= 2) {
          startTime = timeParts[0].trim();
          endTime = timeParts[1].trim();
        }

        newTimetable[foundDay]?.add({
          'title': title,
          'instructor': instructor,
          'start_time': startTime,
          'end_time': endTime,
          'time': '$startTime ~ $endTime',
        });
      }
    }

    _timetable = newTimetable;
  }
}