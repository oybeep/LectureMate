import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  // 요일 목록
  final List<String> _days = ['월', '화', '수', '목', '금'];
  
  // 시간표 데이터: Map<String, List<Map<String, String>>>
  // 예: {'월': [{'title': '인공지능학', 'instructor': '김교수', 'time': '10:00~12:00'}]}
  Map<String, List<Map<String, String>>> _timetable = {
    '월': [],
    '화': [],
    '수': [],
    '목': [],
    '금': [],
  };

  @override
  void initState() {
    super.initState();
    _loadTimetable();
  }

  // 1. SharedPreferences에서 저장된 시간표 불러오기
  Future<void> _loadTimetable() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString('user_timetable');
    
    if (savedData != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(savedData);
        setState(() {
          _timetable = decoded.map((key, value) {
            final list = (value as List).map((item) => Map<String, String>.from(item)).toList();
            return MapEntry(key, list);
          });
        });
      } catch (e) {
        debugPrint('시간표 로딩 에러: $e');
      }
    }
  }

  // 2. SharedPreferences에 시간표 저장하기
  Future<void> _saveTimetable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_timetable', jsonEncode(_timetable));
  }

  // 3. 과목 추가 다이얼로그
  void _showAddClassDialog(String defaultDay) {
    final titleController = TextEditingController();
    final instructorController = TextEditingController();
    final timeController = TextEditingController();
    String selectedDay = defaultDay;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.edit_calendar, color: Colors.indigo),
                  SizedBox(width: 8),
                  Text('시간표 과목 추가'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedDay,
                      decoration: const InputDecoration(
                        labelText: '요일 선택',
                        border: OutlineInputBorder(),
                      ),
                      items: _days.map((day) {
                        return DropdownMenuItem(value: day, child: Text('$day요일'));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedDay = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: '과목명 (예: 데이터 사이언스)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: instructorController,
                      decoration: const InputDecoration(
                        labelText: '교수님 (예: 이교수)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: timeController,
                      decoration: const InputDecoration(
                        labelText: '강의 시간 (예: 13:30 ~ 15:00)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('과목명을 입력해주세요.')),
                      );
                      return;
                    }

                    setState(() {
                      _timetable[selectedDay]!.add({
                        'title': titleController.text.trim(),
                        'instructor': instructorController.text.trim().isEmpty
                            ? '미지정'
                            : instructorController.text.trim(),
                        'time': timeController.text.trim().isEmpty
                            ? '시간 미정'
                            : timeController.text.trim(),
                      });
                    });

                    _saveTimetable();
                    Navigator.pop(context);
                  },
                  child: const Text('등록'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 4. 과목 삭제
  void _removeClass(String day, int index) {
    setState(() {
      _timetable[day]!.removeAt(index);
    });
    _saveTimetable();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('과목이 삭제되었습니다.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _days.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('강의 시간표 관리', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          bottom: TabBar(
            indicatorColor: Colors.indigo,
            labelColor: Colors.indigo,
            unselectedLabelColor: Colors.black54,
            tabs: _days.map((day) => Tab(text: '$day요일')).toList(),
          ),
        ),
        body: TabBarView(
          children: _days.map((day) {
            final classes = _timetable[day] ?? [];

            if (classes.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_note, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text('$day요일에 등록된 강의가 없습니다.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showAddClassDialog(day),
                      icon: const Icon(Icons.add),
                      label: Text('$day요일 과목 추가'),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: classes.length,
              itemBuilder: (context, index) {
                final item = classes[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Colors.indigo.shade100,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                            color: Colors.indigo, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(
                      item['title'] ?? '과목명 없음',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('👨‍🏫 담당: ${item['instructor']}'),
                          const SizedBox(height: 2),
                          Text('⏰ 시간: ${item['time']}',
                              style: TextStyle(color: Colors.indigo.shade700)),
                        ],
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _removeClass(day, index),
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddClassDialog('월'),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('과목 추가'),
        ),
      ),
    );
  }
}