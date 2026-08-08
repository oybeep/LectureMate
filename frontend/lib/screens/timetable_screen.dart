import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/subject_provider.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
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
    Colors.lightGreen.shade100,
    Colors.cyan.shade100,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubjectProvider>().fetchSubjects();
    });
  }

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

  void _showAddOrEditClassDialog({
    required String defaultDay,
    Map<String, String>? existingItem,
    int? editIndex,
  }) {
    final titleController = TextEditingController(text: existingItem?['title'] ?? '');
    final instructorController = TextEditingController(
      text: existingItem?['instructor'] ?? existingItem?['professor'] ?? '',
    );

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
              title: Text(
                existingItem == null ? '✏️ 수강 과목 추가' : '✏️ 수강 과목 수정',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                              showCheckmark: false,
                              visualDensity: VisualDensity.compact,
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
                if (existingItem != null)
                  TextButton(
                    onPressed: () async {
                      final String targetTitle = existingItem['title'] ?? '';
                      final subjects = context.read<SubjectProvider>().subjects;
                      final targetSub = subjects.firstWhere(
                        (s) => (s['title'] ?? s['name']) == targetTitle,
                        orElse: () => null,
                      );

                      if (targetSub != null) {
                        final int subId = int.tryParse(targetSub['id'].toString()) ?? 0;
                        await context.read<SubjectProvider>().deleteSubject(subId);
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

                    final provider = context.read<SubjectProvider>();

                    if (existingItem != null) {
                      final targetSub = provider.subjects.firstWhere(
                        (s) => (s['title'] ?? s['name']) == (existingItem['title'] ?? ''),
                        orElse: () => null,
                      );
                      if (targetSub != null) {
                        final int subId = int.tryParse(targetSub['id'].toString()) ?? 0;
                        await provider.updateSubject(subId, title, instructor, timeSlot);
                      }
                    } else {
                      await provider.addSubject(title, instructor, timeSlot);
                    }

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
    final provider = context.watch<SubjectProvider>();
    final timetable = provider.timetable;
    final subjects = provider.subjects;

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
            onPressed: () => context.read<SubjectProvider>().fetchSubjects(),
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
                          final dayClasses = timetable[day] ?? [];
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

                                // 🎨 과목 인덱스 기반 고유 색상 계산
                                Color tileColor = Colors.indigo.shade100;
                                final String title = item['title'] ?? '';
                                final subjectIndex = subjects.indexWhere(
                                  (s) => (s['title'] ?? s['name']) == title,
                                );

                                if (subjectIndex != -1) {
                                  tileColor = _cardColors[subjectIndex % _cardColors.length];
                                } else {
                                  int charSum = 0;
                                  for (int codeUnit in title.codeUnits) {
                                    charSum += codeUnit;
                                  }
                                  tileColor = _cardColors[charSum % _cardColors.length];
                                }

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
                                              item['instructor'] ?? item['professor'] ?? '',
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