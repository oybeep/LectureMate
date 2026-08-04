import 'package:dio/dio.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../main.dart';

class ApiService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(minutes: 3), // STT/LLM 처리 시간을 고려하여 넉넉히 설정
      headers: {
        'Accept': 'application/json',
      },
    ),
  );

  // 1. 서버 헬스 체크
  Future<bool> checkHealth() async {
    try {
      final response = await _dio.get('/health');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Health check failed: $e');
      return false;
    }
  }

  // 2. 수강 과목 목록 가져오기
  Future<List<dynamic>> getSubjects() async {
    try {
      final response = await _dio.get('/subjects');
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint('Fetch subjects error: $e');
      return [];
    }
  }

  // 3. 음성 파일 업로드 및 전체 분석 (End-to-End STT + 요약 + 퀴즈)
  Future<Map<String, dynamic>> uploadAudioAndAnalyze({
    required String filePath,
    required int subjectId,
  }) async {
    try {
      final file = File(filePath);
      final fileName = filePath.split('/').last;

      final formData = FormData.fromMap({
        'subject_id': subjectId.toString(),
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
      });

      final response = await _dio.post(
        '/lectures/upload',
        data: formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception('Server responded with code ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('통합 분석 요청 중 에러 발생: $e');
    }
  }

  // 4. 과목별 생성된 강의 AI 노트 가져오기
  Future<List<dynamic>> getLecturesBySubject(int subjectId) async {
    try {
      final response = await _dio.get('/subjects/$subjectId/lectures');
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint('Fetch lectures error: $e');
      return [];
    }
  }
}