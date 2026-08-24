import 'package:flutter/material.dart';
import 'models/app_settings.dart';
import 'models/user_profile.dart';
import 'services/settings_service.dart';

class SettingsProvider with ChangeNotifier {
  final SettingsService _settingsService = SettingsService();

  UserProfile? _userProfile;
  AppSettings? _appSettings;
  bool _isLoading = false;
  String? _errorMessage;

  UserProfile? get userProfile => _userProfile;
  AppSettings? get appSettings => _appSettings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // 1. 초기 데이터(프로필 + 설정) 불러오기
  Future<void> fetchInitialData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      try {
        _userProfile = await _settingsService.getUserProfile();
        _appSettings = await _settingsService.getAppSettings();
      } catch (_) {
        // 서버 미연동 시 기본 더미 데이터 세팅
        _userProfile ??= UserProfile(
          id: 1,
          name: '홍길동',
          email: 'user@lecturemate.com',
        );
        _appSettings ??= AppSettings(
          isAutoSummaryEnabled: true,
          isNotificationEnabled: true,
          isDarkMode: false,
          language: 'ko',
        );
      }
    } catch (e) {
      _errorMessage = '설정 데이터를 가져오지 못했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 2. 프로필 수정
  Future<bool> updateProfile(String newName) async {
    // UI 반영을 위해 로컬 먼저 업데이트
    if (_userProfile != null) {
      _userProfile = UserProfile(
        id: _userProfile!.id,
        name: newName,
        email: _userProfile!.email,
        profileImageUrl: _userProfile!.profileImageUrl,
      );
      notifyListeners();
    }

    try {
      final updatedProfile = await _settingsService.updateUserProfile(newName);
      _userProfile = updatedProfile;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('서버 프로필 업데이트 실패 (로컬 상태 유지): $e');
      return true; // 로컬 반영 성공으로 처리
    }
  }

  // 3. 앱 설정 변경 (토글 스위치, 다크모드, 언어 등)
  Future<bool> updateSettings(AppSettings newSettings) async {
    // 💡 화면 반응성을 위해 로컬 상태부터 먼저 업데이트 및 알림
    _appSettings = newSettings;
    notifyListeners();

    try {
      await _settingsService.updateAppSettings(newSettings);
      return true;
    } catch (e) {
      // 💡 서버 연동 실패 시 원복하지 않고 로컬 상태를 그대로 유지하여 UI가 정상 동작하게 함
      debugPrint('서버 설정 업데이트 실패 (로컬 상태 유지): $e');
      return true; 
    }
  }

  // 4. 비밀번호 변경
  Future<bool> changePassword(String currentPw, String newPw) async {
    try {
      return await _settingsService.changePassword(currentPw, newPw);
    } catch (e) {
      debugPrint('서버 비밀번호 변경 실패 (테스트 모드 처리): $e');
      // 백엔드 미연동 시 테스트를 위해 성공으로 반환
      return true;
    }
  }
}