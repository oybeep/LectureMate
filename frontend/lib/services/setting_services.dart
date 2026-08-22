import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/app_settings.dart';
import '../models/user_profile.dart';

class SettingsService {
  // 실제 백엔드 서버 URL (테스트 환경에 맞게 수정)
  static const String baseUrl = 'http://localhost:8000/api/v1';

  // 1. 프로필 정보 조회 (GET /users/me)
  Future<UserProfile> getUserProfile() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/me'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return UserProfile.fromJson(data);
    } else {
      throw Exception('프로필 정보를 불러오는데 실패했습니다.');
    }
  }

  // 2. 프로필 정보 수정 (PATCH /users/me)
  Future<UserProfile> updateUserProfile(String newName) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/users/me'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': newName}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return UserProfile.fromJson(data);
    } else {
      throw Exception('프로필 수정에 실패했습니다.');
    }
  }

  // 3. 앱 설정 정보 조회 (GET /users/settings)
  Future<AppSettings> getAppSettings() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/settings'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return AppSettings.fromJson(data);
    } else {
      throw Exception('앱 설정을 불러오는데 실패했습니다.');
    }
  }

  // 4. 앱 설정 정보 변경 (PATCH /users/settings)
  Future<AppSettings> updateAppSettings(AppSettings settings) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/users/settings'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(settings.toJson()),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return AppSettings.fromJson(data);
    } else {
      throw Exception('설정 변경사항 저장에 실패했습니다.');
    }
  }

  // 5. 비밀번호 변경 (POST /auth/change-password)
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/change-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );

    return response.statusCode == 200;
  }
}