import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final String baseUrl = 'http://127.0.0.1:8000'; // 백엔드 서버 주소

  final List<String> _days = ['월', '화', '수', '목', '금'];
  final List<int> _hours = [9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23];

  final List<Color> _cardColors = [
    Colors.indigo.shade100,
    Colors.teal.shade100,
    Colors.orange.shade100,
    Colors.purple.shade100,
    Colors.blue.shade100,
    Colors.pink.shade100,
    Colors.amber.shade100,
  ];

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
    _fetchSubjectsFromServer(); // 🌐 앱/웹 실행 시 서버에서 먼저 과목 가져오기
  }

  // 1. 백엔드 서버에서 과목 목록 불러오기 (우선 적용)
  Future<void> _fetchSubjectsFromServer() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/subjects/'));
      if (response.statusCode == 200) {
        final List<dynamic> subjects = jsonDecode(utf8.decode(response.bodyBytes));
        
        // 시간표 초기화
        final Map<String, List<Map<String, String>>> newTimetable = {
          '월': [], '화': [], '수': [], '목': [], '금': [],
        };

        for (var sub in subjects) {
          final String title = sub['title'] ?? sub['name'] ?? '미정';
          final String instructor = sub['professor'] ?? sub['instructor'] ?? '미지정';
          final String timeSlot = sub['time_slot'] ?? sub['time'] ?? '수 09:00~10:30';

          // time_slot 문자열 파싱 (예: "수 09:00~10:30" 또는 "수 09:00 ~ 10:30")
          String day = '월';
          String startTime = '09:00';
          String endTime = '10:30';

          for (String d in _days) {
            if (timeSlot.contains(d)) {
              day = d;
              break;
            }
          }

          final timeParts = timeSlot.replaceAll(day, '').trim().split('~');
          if (timeParts.length >= 2) {
            startTime = timeParts[0].trim();
            endTime = timeParts[1].trim();
          }

          newTimetable[day]?.add({
            'title': title,
            'instructor': instructor,
            'start_time': startTime,
            'end_time': endTime,
            'time': '$startTime ~ $endTime',
          });
        }

        setState(() {
          _timetable = newTimetable;
        });
        _saveTimetable(); // 로컬 저장소와도 동기화
      } else {
        _loadTimetable(); // 서버 실패 시 로컬 로드
      }
    } catch (e) {
      debugPrint('서버 과목 로드 실패, 로컬 데이터 로드: $e');
      _loadTimetable();
    }
  }

  // 2. SharedPreferences 로드
  Future<void> _loadTimetable() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString('user_timetable');

    if (savedData != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(savedData);
        setState(() {
          _timetable = decoded.map((key, value) {
            final list = (value as List)
                .map((item) => Map<String, String>.from(item))
                .toList();
            return MapEntry(key, list);
          });
        });
      } catch (e) {
        debugPrint('시간표 로딩 에러: $e');
      }
    }
  }

  // 3. SharedPreferences 저장
  Future<void> _saveTimetable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_timetable', jsonEncode(_timetable));
  }

  // 4. 백엔드 서버 동기화 헬퍼 메서드
  Future<void> _syncSubjectToBackendServer(String title, String professor, String timeSlot) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/subjects/'));
      if (response.statusCode == 200) {
        final List<dynamic> subjects = jsonDecode(utf8.decode(response.bodyBytes));
        int? targetId;
        for (var sub in subjects) {
          if ((sub['title'] ?? sub['name']) == title) {
            targetId = int.tryParse(sub['id'].toString());
            break;
          }
        }

        if (targetId != null) {
          await http.put(
            Uri.parse('$baseUrl/subjects/$targetId'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'title': title,
              'professor': professor,
              'time_slot': timeSlot,
            }),
          );
        } else {
          await http.post(
            Uri.parse('$baseUrl/subjects/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'title': title,
              'professor': professor,
              'time_slot': timeSlot,
            }),
          );
        }
      }
    } catch (e) {
      debugPrint('백엔드 과목 동기화 에러: $e');
    }
  }

  Future<void> _deleteSubjectFromBackendServer(String title) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/subjects/'));
      if (response.statusCode == 200) {
        final List<dynamic> subjects = jsonDecode(utf8.decode(response.bodyBytes));
        for (var sub in subjects) {
          if ((sub['title'] ?? sub['name']) == title) {
            final int targetId = int.parse(sub['id'].toString());
            await http.delete(Uri.parse('$baseUrl/subjects/$targetId'));
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('백엔드 과목 삭제 에러: $e');
    }
  }

  // 5. 시간 변환 및 포맷팅 헬퍼
  int _timeToMinutes(String timeStr) {
    try {
      final parts = timeStr.trim().split(':');
      if (parts.length < 2) return 9 * 60;
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);
      return hour * 60 + minute;
    } catch (_) {
      return 9 * 60;
    }
  }

  TimeOfDay _parseTimeOfDay(String timeStr) {
    try {
      final parts = timeStr.trim().split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

// 6. 과목 추가/수정 다이얼로그
  void _showAddOrEditClassDialog({
    required String defaultDay,
    Map<String, String>? existingItem,
    int? editIndex,
  }) {
    final titleController = TextEditingController(text: existingItem?['title'] ?? '');
    final instructorController = TextEditingController(text: existingItem?['instructor'] ?? '');

    String selectedDay = defaultDay;
    TimeOfDay startTime = _parseTimeOfDay(existingItem?['start_time'] ?? '09:00');
    TimeOfDay endTime = _parseTimeOfDay(existingItem?['end_time'] ?? '10:30');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              title: Row(
                children: [
                  Text(
                    existingItem == null ? '✏️ 수강 과목 추가' : '✏️ 수강 과목 수정',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: '과목명',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: instructorController,
                      decoration: InputDecoration(
                        labelText: '교수님 성함',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('강의 요일', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _days.map((day) {
                          final isSelected = selectedDay == day;
                          return Padding(
                            padding: const EdgeInsets.only(right: 4.0),
                            child: ChoiceChip(
                              showCheckmark: false, // 👈 체크 아이콘 제거
                              visualDensity: VisualDensity.compact, // 👈 여백 축소
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              label: Text(day, style: const TextStyle(fontSize: 13)),
                              selected: isSelected,
                              selectedColor: Theme.of(context).colorScheme.primaryContainer,
                              onSelected: (bool selected) {
                                if (selected) {
                                  setDialogState(() => selectedDay = day);
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('강의 시간', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.access_time, size: 18),
                            label: Text(_formatTimeOfDay(startTime)),
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: startTime,
                              );
                              if (picked != null) {
                                setDialogState(() => startTime = picked);
                              }
                            },
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text('~'),
                        ),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.access_time, size: 18),
                            label: Text(_formatTimeOfDay(endTime)),
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: endTime,
                              );
                              if (picked != null) {
                                setDialogState(() => endTime = picked);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                if (existingItem != null && editIndex != null)
                  TextButton(
                    onPressed: () async {
                      final String oldTitle = existingItem['title'] ?? '';
                      setState(() {
                        _timetable[defaultDay]!.removeAt(editIndex);
                      });
                      await _saveTimetable();
                      if (oldTitle.isNotEmpty) {
                        await _deleteSubjectFromBackendServer(oldTitle);
                      }
                      if (mounted) Navigator.pop(context);
                    },
                    child: const Text('삭제', style: TextStyle(color: Colors.red)),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('과목명을 입력해주세요.')),
                      );
                      return;
                    }

                    final String title = titleController.text.trim();
                    final String instructor = instructorController.text.trim().isEmpty
                        ? '미지정'
                        : instructorController.text.trim();
                    final String startStr = _formatTimeOfDay(startTime);
                    final String endStr = _formatTimeOfDay(endTime);
                    final String timeSlot = '$selectedDay $startStr~$endStr';

                    final newItem = {
                      'title': title,
                      'instructor': instructor,
                      'start_time': startStr,
                      'end_time': endStr,
                      'time': '$startStr ~ $endStr',
                    };

                    setState(() {
                      if (existingItem != null && editIndex != null) {
                        _timetable[defaultDay]!.removeAt(editIndex);
                      }
                      _timetable[selectedDay]!.add(newItem);
                    });

                    await _saveTimetable();
                    await _syncSubjectToBackendServer(title, instructor, timeSlot);

                    if (mounted) Navigator.pop(context);
                  },
                  child: Text(existingItem == null ? '추가' : '수정'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const double rowHeight = 60.0;
    const int startHour = 9;

    return Scaffold(
      appBar: AppBar(
        title: const Text('주간 시간표', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: _fetchSubjectsFromServer,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '과목 추가',
            onPressed: () => _showAddOrEditClassDialog(defaultDay: '월'),
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                const SizedBox(width: 45, child: Center(child: Text('시간', style: TextStyle(fontSize: 12, color: Colors.grey)))),
                ..._days.map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    )),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: SingleChildScrollView(
              child: SizedBox(
                height: _hours.length * rowHeight,
                child: Stack(
                  children: [
                    Column(
                      children: _hours.map((hour) {
                        return Container(
                          height: rowHeight,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade300, width: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 45,
                                child: Center(
                                  child: Text(
                                    '$hour시',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ),
                              ),
                              ..._days.map((_) => Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border(
                                          left: BorderSide(color: Colors.grey.shade200, width: 0.5),
                                        ),
                                      ),
                                    ),
                                  )),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    Row(
                      children: [
                        const SizedBox(width: 45),
                        ..._days.map((day) {
                          final dayClasses = _timetable[day] ?? [];
                          return Expanded(
                            child: Stack(
                              children: dayClasses.asMap().entries.map((entry) {
                                int index = entry.key;
                                var item = entry.value;

                                int startMin = _timeToMinutes(item['start_time'] ?? item['time'] ?? '09:00');
                                int endMin = _timeToMinutes(item['end_time'] ?? '10:30');

                                double topPosition = ((startMin - (startHour * 60)) / 60.0) * rowHeight;
                                double tileHeight = ((endMin - startMin) / 60.0) * rowHeight;
                                if (tileHeight < 30) tileHeight = 30;

                                Color tileColor = _cardColors[(item['title'].hashCode).abs() % _cardColors.length];

                                return Positioned(
                                  top: topPosition + 1,
                                  left: 1,
                                  right: 1,
                                  height: tileHeight - 2,
                                  child: GestureDetector(
                                    onTap: () => _showAddOrEditClassDialog(
                                      defaultDay: day,
                                      existingItem: item,
                                      editIndex: index,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(4.0),
                                      decoration: BoxDecoration(
                                        color: tileColor,
                                        borderRadius: BorderRadius.circular(6),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black12,
                                            blurRadius: 2,
                                            offset: Offset(0, 1),
                                          )
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['title'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (tileHeight > 45) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              item['instructor'] ?? '',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.black54,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
