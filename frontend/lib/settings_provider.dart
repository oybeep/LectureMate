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

  // 1. 초기 데이터(프로필 + 설정) 한 번에 불러오기
  Future<void> fetchInitialData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 서버 미연동 시 앱 튕김 방지를 위한 더미/기본값 백업 처리
      try {
        _userProfile = await _settingsService.getUserProfile();
        _appSettings = await _settingsService.getAppSettings();
      } catch (_) {
        // 백엔드가 아직 준비되지 않은 경우 기본값 세팅
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
    try {
      final updatedProfile = await _settingsService.updateUserProfile(newName);
      _userProfile = updatedProfile;
      notifyListeners();
      return true;
    } catch (e) {
      // 서버 미연동 시 로컬 상태 우선 업데이트
      if (_userProfile != null) {
        _userProfile = UserProfile(
          id: _userProfile!.id,
          name: newName,
          email: _userProfile!.email,
          profileImageUrl: _userProfile!.profileImageUrl,
        );
        notifyListeners();
        return true;
      }
      return false;
    }
  }

  // 3. 앱 설정 변경 (토글 스위치 등)
  Future<bool> updateSettings(AppSettings newSettings) async {
    final oldSettings = _appSettings;
    _appSettings = newSettings;
    notifyListeners();

    try {
      await _settingsService.updateAppSettings(newSettings);
      return true;
    } catch (e) {
      // 실패 시 기존 설정값으로 원복
      _appSettings = oldSettings;
      notifyListeners();
      return false;
    }
  }

  // 4. 비밀번호 변경
  Future<bool> changePassword(String currentPw, String newPw) async {
    try {
      return await _settingsService.changePassword(currentPw, newPw);
    } catch (e) {
      return false;
    }
  }
}