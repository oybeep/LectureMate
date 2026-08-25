import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'main.dart'; // ApiConfig 참조

class SubjectProvider extends ChangeNotifier {
  List<dynamic> _subjects = [];
  Map<String, List<Map<String, String>>> _timetable = {
    '월': [], '화': [], '수': [], '목': [], '금': [],
  };

  bool _isLoading = false;
  String? _errorMessage;

  List<dynamic> get subjects => _subjects;
  Map<String, List<Map<String, String>>> get timetable => _timetable;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // 에러 메시지 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // 서버에서 과목 목록 불러오기
  Future<void> fetchSubjects() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final baseUrl = ApiConfig.baseUrl;
      final response = await http
          .get(Uri.parse('$baseUrl/subjects/'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        _subjects = data;
        _buildTimetable();
      } else {
        _errorMessage = '과목 목록을 불러오지 못했습니다. (코드: ${response.statusCode})';
      }
    } on TimeoutException {
      _errorMessage = '서버 응답 시간이 초과되었습니다. 네트워크 상태를 확인해주세요.';
    } on SocketException {
      _errorMessage = '백엔드 서버에 연결할 수 없습니다.';
    } on FormatException {
      _errorMessage = '서버 응답 데이터 형식이 올바르지 않습니다.';
    } catch (e) {
      _errorMessage = '알 수 없는 오류가 발생했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 과목 추가
  Future<bool> addSubject(String title, String professor, String timeSlot) async {
    _errorMessage = null;
    try {
      final baseUrl = ApiConfig.baseUrl;
      final response = await http
          .post(
            Uri.parse('$baseUrl/subjects/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'title': title,
              'professor': professor,
              'time_slot': timeSlot,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchSubjects();
        return true;
      } else {
        _errorMessage = '과목 등록 실패 (코드: ${response.statusCode})';
        notifyListeners();
        return false;
      }
    } on TimeoutException {
      _errorMessage = '요청 시간이 초과되었습니다.';
    } on SocketException {
      _errorMessage = '서버에 연결할 수 없습니다.';
    } catch (e) {
      _errorMessage = '과목 추가 중 오류 발생: $e';
    }
    notifyListeners();
    return false;
  }

  // 과목 수정
  Future<bool> updateSubject(int id, String title, String professor, String timeSlot) async {
    _errorMessage = null;
    try {
      final baseUrl = ApiConfig.baseUrl;
      final response = await http
          .put(
            Uri.parse('$baseUrl/subjects/$id'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'title': title,
              'professor': professor,
              'time_slot': timeSlot,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        await fetchSubjects();
        return true;
      } else {
        _errorMessage = '과목 수정 실패 (코드: ${response.statusCode})';
        notifyListeners();
        return false;
      }
    } on TimeoutException {
      _errorMessage = '요청 시간이 초과되었습니다.';
    } on SocketException {
      _errorMessage = '서버에 연결할 수 없습니다.';
    } catch (e) {
      _errorMessage = '과목 수정 중 오류 발생: $e';
    }
    notifyListeners();
    return false;
  }

  // 과목 삭제
  Future<bool> deleteSubject(int id) async {
    _errorMessage = null;
    try {
      final baseUrl = ApiConfig.baseUrl;
      final response = await http
          .delete(Uri.parse('$baseUrl/subjects/$id'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        await fetchSubjects();
        return true;
      } else {
        _errorMessage = '과목 삭제 실패 (코드: ${response.statusCode})';
        notifyListeners();
        return false;
      }
    } on TimeoutException {
      _errorMessage = '요청 시간이 초과되었습니다.';
    } on SocketException {
      _errorMessage = '서버에 연결할 수 없습니다.';
    } catch (e) {
      _errorMessage = '과목 삭제 중 오류 발생: $e';
    }
    notifyListeners();
    return false;
  }

  // 과목 리스트를 기반으로 Timetable 맵을 생성하는 메서드
  void _buildTimetable() {
    final Map<String, List<Map<String, String>>> newTimetable = {
      '월': [], '화': [], '수': [], '목': [], '금': [],
    };

    final List<String> days = ['월', '화', '수', '목', '금'];

    for (var sub in _subjects) {
      final String title = sub['title'] ?? sub['name'] ?? '미정';
      final String instructor =
          sub['professor'] ?? sub['instructor'] ?? sub['professor_name'] ?? '미지정';

      final String timeSlot =
          (sub['time_slot'] ?? sub['time'] ?? sub['time_info'] ?? '').toString().trim();

      if (timeSlot.isEmpty) continue;

      String foundDay = '';
      for (String d in days) {
        if (timeSlot.contains(d)) {
          foundDay = d;
          break;
        }
      }

      if (foundDay.isNotEmpty) {
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