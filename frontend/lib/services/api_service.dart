import 'package:dio/dio.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../main.dart';

class ApiService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(minutes: 10), // 대용량 음성 업로드 시간 고려 (10분)
      receiveTimeout: const Duration(minutes: 10), // STT, AI 요약, DB 처리 시간을 고려하여 넉넉히 설정 (10분)
      headers: {
        'Accept': 'application/json',
      },
    ),
  );

  // 1. 서버 헬스 체크 (/health)
  Future<bool> checkHealth() async {
    try {
      final response = await _dio.get('/health');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Health check failed: $e');
      return false;
    }
  }

  // 2. 수강 과목 목록 가져오기 (/subjects)
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

  // 3. 음성 파일 업로드 및 전체 분석 요청 (/lectures/upload)
  // End-to-End: STT -> 요약 -> 퀴즈 생성 한 번에 처리
  Future<Map<String, dynamic>> uploadAudioAndAnalyze({
    required String filePath,
    required int subjectId,
    List<int>? bytes, // 웹 녹음 시 바이너리 데이터 수신용 추가
  }) async {
    try {
      final fileName = filePath.split('/').last.isEmpty ? 'recorded_audio.wav' : filePath.split('/').last;

      MultipartFile multipartFile;

      if (kIsWeb && bytes != null) {
        // 웹(Chrome) 환경일 경우 바이트로 생성
        multipartFile = MultipartFile.fromBytes(bytes, filename: fileName);
      } else {
        // 모바일/데스크톱 환경일 경우 파일 경로 사용
        final file = File(filePath);
        multipartFile = await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        );
      }

      final formData = FormData.fromMap({
        'subject_id': subjectId.toString(),
        'file': multipartFile,
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

  // 4. 과목별 생성된 강의 AI 노트 목록 가져오기 (/subjects/{id}/lectures)
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

  // 5. 강의 삭제하기 (/lectures/{id}) - 새로 추가된 메서드
  Future<bool> deleteLecture(dynamic lectureId) async {
    try {
      final response = await _dio.delete('/lectures/$lectureId');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Delete lecture error: $e');
      return false;
    }
  }

  // 6. 강의 제목 수정하기 (/lectures/{id}) - 새로 추가된 메서드
  Future<bool> updateLectureTitle(dynamic lectureId, String newTitle) async {
    try {
      final response = await _dio.patch(
        '/lectures/$lectureId',
        data: {'title': newTitle},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Update lecture title error: $e');
      return false;
    }
  }
}