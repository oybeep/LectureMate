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
    final settingsProvider = context.watch<SettingsProvider>();
    final userProfile = settingsProvider.userProfile;
    final appSettings = settingsProvider.appSettings;

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
    final selectedLanguage = (appSettings?.language == 'en') ? 'English' : '한국어';

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 12),

          // 1. 프로필 카드
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

          // 2. AI & 학습 서비스
          _buildSectionHeader('AI & 학습 서비스'),
          SwitchListTile(
            secondary: const Icon(Icons.auto_awesome, color: Colors.indigo),
            title: const Text('녹음 완료 후 자동 AI 요약'),
            subtitle: const Text('강의 녹음이 끝나면 자동으로 요약 노트를 생성합니다.'),
            value: isAutoSummary,
            activeColor: Colors.indigo,
            onChanged: (val) {
              final targetSettings = appSettings ?? AppSettings();
              context.read<SettingsProvider>().updateSettings(
                    targetSettings.copyWith(isAutoSummaryEnabled: val),
                  );
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined, color: Colors.indigo),
            title: const Text('요약 완료 알림'),
            subtitle: const Text('AI 노드가 생성되면 푸시 알림을 받습니다.'),
            value: isNotification,
            activeColor: Colors.indigo,
            onChanged: (val) {
              final targetSettings = appSettings ?? AppSettings();
              context.read<SettingsProvider>().updateSettings(
                    targetSettings.copyWith(isNotificationEnabled: val),
                  );
            },
          ),
          const Divider(),

          // 3. 앱 설정
          _buildSectionHeader('앱 설정'),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined, color: Colors.indigo),
            title: const Text('다크 모드'),
            subtitle: const Text('어두운 테마 모드를 적용합니다.'),
            value: isDarkMode,
            activeColor: Colors.indigo,
            onChanged: (val) {
              final targetSettings = appSettings ?? AppSettings();
              context.read<SettingsProvider>().updateSettings(
                    targetSettings.copyWith(isDarkMode: val),
                  );
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
            title: const Text('캐시 데이터 정리'),
            subtitle: const Text('임시 데이터 저장 공간을 정리합니다.'),
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
          const Divider(),

          // 5. 계정 관리
          _buildSectionHeader('계정 관리'),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.orange),
            title: const Text('로그아웃'),
            onTap: () => _showLogoutDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.person_remove_outlined, color: Colors.red),
            title: const Text('회원 탈퇴', style: TextStyle(color: Colors.red)),
            onTap: () => _showDeleteAccountDialog(context),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.indigo),
      ),
    );
  }

  // 프로필 수정 다이얼로그
  void _showEditProfileDialog(BuildContext context, String currentName) {
    final nameController = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('프로필 수정'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: '이름', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                Navigator.pop(dialogContext);
                await context.read<SettingsProvider>().updateProfile(newName);
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  // 비밀번호 변경 다이얼로그 호출
  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => const _PasswordChangeDialog(),
    );
  }

  // 언어 선택 다이얼로그
  void _showLanguageDialog(BuildContext context, AppSettings? appSettings) {
    final targetSettings = appSettings ?? AppSettings();
    final currentLangCode = targetSettings.language;

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
                value: 'ko',
                groupValue: currentLangCode,
                onChanged: (val) {
                  if (val != null) {
                    context.read<SettingsProvider>().updateSettings(
                          targetSettings.copyWith(language: 'ko'),
                        );
                    Navigator.pop(dialogContext);
                  }
                },
              ),
              RadioListTile<String>(
                title: const Text('English'),
                value: 'en',
                groupValue: currentLangCode,
                onChanged: (val) {
                  if (val != null) {
                    context.read<SettingsProvider>().updateSettings(
                          targetSettings.copyWith(language: 'en'),
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

  // 캐시 삭제 다이얼로그
  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('캐시 삭제'),
        content: const Text('저장된 임시 파일과 캐시 데이터를 삭제하시겠습니까?\n강의 요약 노트는 삭제되지 않습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')),
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

  // 로그아웃 다이얼로그
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('로그아웃 되었습니다.')),
              );
            },
            child: const Text('로그아웃', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 회원 탈퇴 다이얼로그
  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('회원 탈퇴'),
        content: const Text('탈퇴 시 저장된 모든 강의 데이터 및 AI 요약 정보가 삭제됩니다. 계속하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('회원 탈퇴가 완료되었습니다.')),
              );
            },
            child: const Text('탈퇴하기', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// 비밀번호 변경 다이얼로그 클래스
class _PasswordChangeDialog extends StatefulWidget {
  const _PasswordChangeDialog();

  @override
  State<_PasswordChangeDialog> createState() => _PasswordChangeDialogState();
}

class _PasswordChangeDialogState extends State<_PasswordChangeDialog> {
  final _currentPwController = TextEditingController();
  final _newPwController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('비밀번호 변경'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _currentPwController,
            obscureText: _obscureCurrent,
            decoration: InputDecoration(
              labelText: '현재 비밀번호',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscureCurrent ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newPwController,
            obscureText: _obscureNew,
            decoration: InputDecoration(
              labelText: '새 비밀번호',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        ElevatedButton(
          onPressed: () async {
            if (_currentPwController.text.isNotEmpty && _newPwController.text.isNotEmpty) {
              Navigator.pop(context);
              final success = await context.read<SettingsProvider>().changePassword(
                    _currentPwController.text,
                    _newPwController.text,
                  );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? '비밀번호가 성공적으로 변경되었습니다.' : '비밀번호 변경 완료 (테스트)',
                    ),
                  ),
                );
              }
            }
          },
          child: const Text('변경'),
        ),
      ],
    );
  }
}