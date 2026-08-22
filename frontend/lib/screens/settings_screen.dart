import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../settings_provider.dart';
import '../models/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    // Provider 구독 (상태 변화 시 UI 자동 리렌더링)
    final settingsProvider = context.watch<SettingsProvider>();
    final userProfile = settingsProvider.userProfile;
    final appSettings = settingsProvider.appSettings;

    // 로딩 중 처리
    if (settingsProvider.isLoading && userProfile == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('설정', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final userName = userProfile?.name ?? '사용자';
    final userEmail = userProfile?.email ?? 'user@lecturemate.com';
    final isAutoSummary = appSettings?.isAutoSummaryEnabled ?? true;
    final isNotification = appSettings?.isNotificationEnabled ?? true;
    final isDarkMode = appSettings?.isDarkMode ?? false;
    final selectedLanguage = appSettings?.language == 'en' ? 'English' : '한국어';

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 12),

          // 1. 사용자 프로필 카드
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.indigo,
                child: Text(
                  userName.isNotEmpty ? userName[0] : 'U',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(userEmail),
              trailing: const Icon(Icons.edit_outlined, size: 20),
              onTap: () => _showEditProfileDialog(context, userName),
            ),
          ),
          const SizedBox(height: 12),

          // 2. AI & 학습 서비스 설정
          _buildSectionHeader('AI & 학습 서비스'),
          SwitchListTile(
            secondary: const Icon(Icons.auto_awesome, color: Colors.indigo),
            title: const Text('녹음 완료 후 자동 AI 요약'),
            subtitle: const Text('강의 녹음이 끝나면 자동으로 요약 노트를 생성합니다.'),
            value: isAutoSummary,
            activeColor: Colors.indigo,
            onChanged: (val) {
              if (appSettings != null) {
                context.read<SettingsProvider>().updateSettings(
                      appSettings.copyWith(isAutoSummaryEnabled: val),
                    );
              }
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined, color: Colors.indigo),
            title: const Text('요약 완료 알림'),
            subtitle: const Text('AI 노드가 생성되면 푸시 알림을 받습니다.'),
            value: isNotification,
            activeColor: Colors.indigo,
            onChanged: (val) {
              if (appSettings != null) {
                context.read<SettingsProvider>().updateSettings(
                      appSettings.copyWith(isNotificationEnabled: val),
                    );
              }
            },
          ),
          const Divider(),

          // 3. 앱 일반 설정
          _buildSectionHeader('앱 설정'),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined, color: Colors.indigo),
            title: const Text('다크 모드'),
            subtitle: const Text('어두운 테마 모드를 적용합니다.'),
            value: isDarkMode,
            activeColor: Colors.indigo,
            onChanged: (val) {
              if (appSettings != null) {
                context.read<SettingsProvider>().updateSettings(
                      appSettings.copyWith(isDarkMode: val),
                    );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('다크모드 설정이 변경되었습니다.'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.language, color: Colors.indigo),
            title: const Text('언어 (Language)'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(selectedLanguage, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
            onTap: () => _showLanguageDialog(context, appSettings),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined, color: Colors.indigo),
            title: const Text('캐시 데이터 삭제'),
            subtitle: const Text('음성 임시 파일 및 캐시 데이터를 정리합니다.'),
            onTap: () => _showClearCacheDialog(context),
          ),
          const Divider(),

          // 4. 보안 및 정보
          _buildSectionHeader('계정 보안 및 정보'),
          ListTile(
            leading: const Icon(Icons.lock_outline, color: Colors.indigo),
            title: const Text('비밀번호 변경'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showChangePasswordDialog(context),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline, color: Colors.indigo),
            title: Text('앱 버전'),
            trailing: Text('v1.0.0', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined, color: Colors.indigo),
            title: const Text('서비스 이용약관'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined, color: Colors.indigo),
            title: const Text('개인정보 처리방침'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text(
              '로그아웃',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
            onTap: () => _showLogoutDialog(context),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // 섹션 제목 헬퍼 위젯
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.indigo,
        ),
      ),
    );
  }

  // 1) 프로필 수정 다이얼로그
  void _showEditProfileDialog(BuildContext context, String currentName) {
    final nameController = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('프로필 수정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '이름',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                Navigator.pop(dialogContext);
                final success = await context.read<SettingsProvider>().updateProfile(newName);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? '프로필 정보가 수정되었습니다.' : '프로필 수정 실패'),
                    ),
                  );
                }
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  // 2) 비밀번호 변경 다이얼로그
  void _showChangePasswordDialog(BuildContext context) {
    final currentPwController = TextEditingController();
    final newPwController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('비밀번호 변경'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPwController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '현재 비밀번호',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPwController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '새 비밀번호',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (currentPwController.text.isNotEmpty && newPwController.text.isNotEmpty) {
                Navigator.pop(dialogContext);
                final success = await context.read<SettingsProvider>().changePassword(
                      currentPwController.text,
                      newPwController.text,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? '비밀번호가 성공적으로 변경되었습니다.' : '비밀번호 변경에 실패했습니다.'),
                    ),
                  );
                }
              }
            },
            child: const Text('변경'),
          ),
        ],
      ),
    );
  }

  // 3) 언어 선택 다이얼로그
  void _showLanguageDialog(BuildContext context, AppSettings? appSettings) {
    if (appSettings == null) return;
    final currentLang = appSettings.language == 'en' ? 'English' : '한국어';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('언어 선택'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('한국어'),
                value: '한국어',
                groupValue: currentLang,
                onChanged: (val) {
                  if (val != null) {
                    context.read<SettingsProvider>().updateSettings(
                          appSettings.copyWith(language: 'ko'),
                        );
                    Navigator.pop(dialogContext);
                  }
                },
              ),
              RadioListTile<String>(
                title: const Text('English'),
                value: 'English',
                groupValue: currentLang,
                onChanged: (val) {
                  if (val != null) {
                    context.read<SettingsProvider>().updateSettings(
                          appSettings.copyWith(language: 'en'),
                        );
                    Navigator.pop(dialogContext);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 4) 캐시 삭제 다이얼로그
  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('캐시 삭제'),
        content: const Text('저장된 임시 파일과 캐시 데이터를 삭제하시겠습니까?\n강의 요약 노트는 삭제되지 않습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('캐시 데이터가 성공적으로 정리되었습니다.')),
              );
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  // 5) 로그아웃 다이얼로그
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(dialogContext);
              // TODO: 실제 로그인 페이지 이동 또는 인증 토큰 삭제 처리
            },
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }
}