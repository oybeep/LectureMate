import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 설정 상태 변수들
  bool _isNotificationEnabled = true;
  bool _isAutoSummaryEnabled = true;
  bool _isDarkMode = false;
  String _selectedLanguage = '한국어';

  // 사용자 프로필 임시 데이터
  String _userName = '홍길동';
  String _userEmail = 'user@lecturemate.com';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // 로컬 저장소에서 설정값 불러오기
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isNotificationEnabled = prefs.getBool('isNotificationEnabled') ?? true;
      _isAutoSummaryEnabled = prefs.getBool('isAutoSummaryEnabled') ?? true;
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _selectedLanguage = prefs.getString('selectedLanguage') ?? '한국어';
      _userName = prefs.getString('userName') ?? '홍길동';
      _userEmail = prefs.getString('userEmail') ?? 'user@lecturemate.com';
    });
  }

  // 설정값 변경 시 로컬 저장소에 저장
  Future<void> _saveBoolSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveStringSetting(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  @override
  Widget build(BuildContext context) {
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
                  _userName.isNotEmpty ? _userName[0] : 'U',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(_userName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_userEmail),
              trailing: const Icon(Icons.edit_outlined, size: 20),
              onTap: _showEditProfileDialog,
            ),
          ),
          const SizedBox(height: 12),

          // 2. AI & 학습 서비스 설정
          _buildSectionHeader('AI & 학습 서비스'),
          SwitchListTile(
            secondary: const Icon(Icons.auto_awesome, color: Colors.indigo),
            title: const Text('녹음 완료 후 자동 AI 요약'),
            subtitle: const Text('강의 녹음이 끝나면 자동으로 요약 노트를 생성합니다.'),
            value: _isAutoSummaryEnabled,
            activeColor: Colors.indigo,
            onChanged: (val) {
              setState(() => _isAutoSummaryEnabled = val);
              _saveBoolSetting('isAutoSummaryEnabled', val);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined, color: Colors.indigo),
            title: const Text('요약 완료 알림'),
            subtitle: const Text('AI 노드가 생성되면 푸시 알림을 받습니다.'),
            value: _isNotificationEnabled,
            activeColor: Colors.indigo,
            onChanged: (val) {
              setState(() => _isNotificationEnabled = val);
              _saveBoolSetting('isNotificationEnabled', val);
            },
          ),
          const Divider(),

          // 3. 앱 일반 설정
          _buildSectionHeader('앱 설정'),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined, color: Colors.indigo),
            title: const Text('다크 모드'),
            subtitle: const Text('어두운 테마 모드를 적용합니다.'),
            value: _isDarkMode,
            activeColor: Colors.indigo,
            onChanged: (val) {
              setState(() => _isDarkMode = val);
              _saveBoolSetting('isDarkMode', val);
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('다크모드 설정이 변경되었습니다.'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.language, color: Colors.indigo),
            title: const Text('언어 (Language)'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_selectedLanguage, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
            onTap: _showLanguageDialog,
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined, color: Colors.indigo),
            title: const Text('캐시 데이터 삭제'),
            subtitle: const Text('음성 임시 파일 및 캐시 데이터를 정리합니다.'),
            onTap: _showClearCacheDialog,
          ),
          const Divider(),

          // 4. 보안 및 정보
          _buildSectionHeader('계정 보안 및 정보'),
          ListTile(
            leading: const Icon(Icons.lock_outline, color: Colors.indigo),
            title: const Text('비밀번호 변경'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showChangePasswordDialog,
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
            onTap: _showLogoutDialog,
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
  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _userName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                setState(() => _userName = newName);
                _saveStringSetting('userName', newName);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('프로필 정보가 수정되었습니다.')),
                );
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  // 2) 비밀번호 변경 다이얼로그
  void _showChangePasswordDialog() {
    final currentPwController = TextEditingController();
    final newPwController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              if (currentPwController.text.isNotEmpty && newPwController.text.isNotEmpty) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('비밀번호가 성공적으로 변경되었습니다.')),
                );
              }
            },
            child: const Text('변경'),
          ),
        ],
      ),
    );
  }

  // 3) 언어 선택 다이얼로그
  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('언어 선택'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('한국어'),
                value: '한국어',
                groupValue: _selectedLanguage,
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedLanguage = val);
                    _saveStringSetting('selectedLanguage', val);
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<String>(
                title: const Text('English'),
                value: 'English',
                groupValue: _selectedLanguage,
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedLanguage = val);
                    _saveStringSetting('selectedLanguage', val);
                    Navigator.pop(context);
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
  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('캐시 삭제'),
        content: const Text('저장된 임시 파일과 캐시 데이터를 삭제하시겠습니까?\n강의 요약 노트는 삭제되지 않습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
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
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              // TODO: 실제 로그아웃 로직 처리
            },
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }
}