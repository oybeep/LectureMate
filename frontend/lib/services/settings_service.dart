import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../models/user_profile.dart';

class SettingsService {
  static const String baseUrl = 'http://localhost:8000/api/v1';

  static const String _keyProfile = 'user_profile_data';
  static const String _keySettings = 'app_settings_data';

  // 1. 프로필 조회 (서버 호출 ➡️ 실패 시 SharedPreferences)
  Future<UserProfile> getUserProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/me'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final profile = UserProfile.fromJson(data);
        
        // 서버 데이터 수신 성공 시 로컬 저장소 캐시 갱신
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyProfile, jsonEncode(profile.toJson()));
        
        return profile;
      }
    } catch (_) {
      // 서버 미연동 또는 실패 시 로컬 로드 진행
    }

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyProfile);
    if (jsonString != null) {
      return UserProfile.fromJson(jsonDecode(jsonString));
    }

    return UserProfile(
      id: 1,
      name: '홍길동',
      email: 'user@lecturemate.com',
    );
  }

  // 2. 프로필 수정 (로컬 저장 + 서버 전송)
  Future<UserProfile> updateUserProfile(String newName) async {
    final currentProfile = await getUserProfile();
    final updated = UserProfile(
      id: currentProfile.id,
      name: newName,
      email: currentProfile.email,
      profileImageUrl: currentProfile.profileImageUrl,
    );

    // 로컬 저장소 우선 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfile, jsonEncode(updated.toJson()));

    // 백엔드 서버 전송
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/users/me'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': newName}),
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return UserProfile.fromJson(data);
      }
    } catch (_) {}

    return updated;
  }

  // 3. 앱 설정 조회 (백엔드 URL 경로 수정: /settings)
  Future<AppSettings> getAppSettings() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/settings'), // 💡 /users/settings -> /settings 수정
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final settings = AppSettings.fromJson(data);

        // 서버 데이터 수신 성공 시 로컬 저장소 캐시 갱신
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keySettings, jsonEncode(settings.toJson()));

        return settings;
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keySettings);
    if (jsonString != null) {
      return AppSettings.fromJson(jsonDecode(jsonString));
    }

    return AppSettings(
      isAutoSummaryEnabled: true,
      isNotificationEnabled: true,
      isDarkMode: false,
      language: 'ko',
    );
  }

  // 4. 앱 설정 변경 (백엔드 URL 경로 수정: /settings)
  Future<AppSettings> updateAppSettings(AppSettings settings) async {
    // 로컬 저장소 우선 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySettings, jsonEncode(settings.toJson()));

    // 백엔드 서버 전송
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/settings'), // 💡 /users/settings -> /settings 수정
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(settings.toJson()),
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return AppSettings.fromJson(data);
      }
    } catch (_) {}

    return settings;
  }

  // 5. 비밀번호 변경
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/change-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      ).timeout(const Duration(seconds: 2));

      return response.statusCode == 200;
    } catch (_) {
      return true;
    }
  }
}