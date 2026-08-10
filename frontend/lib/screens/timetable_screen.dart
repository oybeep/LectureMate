import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/subject_provider.dart';

// ---------------------------------------------------------------------------
// 🗓️ 동적 수업 일정 모델 (요일, 시간, 강의실)
// ---------------------------------------------------------------------------
class CourseScheduleItem {
  String day;
  TimeOfDay startTime;
  TimeOfDay endTime;
  String room;

  CourseScheduleItem({
    required this.day,
    required this.startTime,
    required this.endTime,
    this.room = '',
  });

  String toSlotString() {
    final startStr =
        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    final endStr =
        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    final roomStr = room.trim().isNotEmpty ? ' ($room)' : '';
    return '$day $startStr~$endStr$roomStr';
  }

  static CourseScheduleItem fromSlotString(String slot) {
    String day = '월';
    TimeOfDay start = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 10, minute: 30);
    String room = '';

    try {
      final roomReg = RegExp(r'\((.*?)\)');
      final roomMatch = roomReg.firstMatch(slot);
      if (roomMatch != null) {
        room = roomMatch.group(1) ?? '';
      }

      final cleanSlot = slot.replaceAll(RegExp(r'\s*\(.*?\)\s*'), '').trim();
      final parts = cleanSlot.split(' ');
      if (parts.isNotEmpty && ['월', '화', '수', '목', '금', '토'].contains(parts[0])) {
        day = parts[0];
      }

      if (parts.length > 1 && parts[1].contains('~')) {
        final times = parts[1].split('~');
        final startSplit = times[0].split(':');
        final endSplit = times[1].split(':');
        start = TimeOfDay(
            hour: int.parse(startSplit[0]), minute: int.parse(startSplit[1]));
        end = TimeOfDay(
            hour: int.parse(endSplit[0]), minute: int.parse(endSplit[1]));
      }
    } catch (_) {}

    return CourseScheduleItem(
        day: day, startTime: start, endTime: end, room: room);
  }
}

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final List<String> _days = ['월', '화', '수', '목', '금'];
  final List<int> _hours = [
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
    23
  ];

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

  // ---------------------------------------------------------------------------
  // 🗓️ 동적 시간표 리스트 다이얼로그 위젯
  // ---------------------------------------------------------------------------
  Widget _buildScheduleEditor(
    List<CourseScheduleItem> schedules,
    StateSetter setDialogState,
  ) {
    String formatTime(TimeOfDay t) {
      final hour = t.hour.toString().padLeft(2, '0');
      final minute = t.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }

    Future<void> pickTime(CourseScheduleItem item, bool isStart) async {
      final picked = await showTimePicker(
        context: context,
        initialTime: isStart ? item.startTime : item.endTime,
      );
      if (picked != null) {
        setDialogState(() {
          if (isStart) {
            item.startTime = picked;
          } else {
            item.endTime = picked;
          }
        });
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('수업 일정 목록',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            TextButton.icon(
              onPressed: () {
                setDialogState(() {
                  schedules.add(CourseScheduleItem(
                    day: '화',
                    startTime: const TimeOfDay(hour: 11, minute: 0),
                    endTime: const TimeOfDay(hour: 12, minute: 30),
                  ));
                });
              },
              icon: const Icon(Icons.add_circle_outline, size: 16),
              label: const Text('시간 추가', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...schedules.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: Colors.grey.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      DropdownButton<String>(
                        value: item.day,
                        underline: const SizedBox(),
                        items: ['월', '화', '수', '목', '금', '토'].map((d) {
                          return DropdownMenuItem(
                              value: d,
                              child: Text(d,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => item.day = val);
                        },
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6)),
                        onPressed: () => pickTime(item, true),
                        child: Text(formatTime(item.startTime),
                            style: const TextStyle(fontSize: 12)),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2.0),
                        child: Text('~', style: TextStyle(fontSize: 12)),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6)),
                        onPressed: () => pickTime(item, false),
                        child: Text(formatTime(item.endTime),
                            style: const TextStyle(fontSize: 12)),
                      ),
                      const Spacer(),
                      if (schedules.length > 1)
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.remove_circle,
                              color: Colors.redAccent, size: 18),
                          onPressed: () =>
                              setDialogState(() => schedules.removeAt(idx)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: '강의실 (예: E동 513호)',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(),
                    ),
                    controller: TextEditingController(text: item.room)
                      ..selection =
                          TextSelection.collapsed(offset: item.room.length),
                    onChanged: (val) => item.room = val,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _showAddOrEditClassDialog({
    required String defaultDay,
    Map<String, dynamic>? existingItem,
  }) {
    final titleController =
        TextEditingController(text: existingItem?['title'] ?? '');
    final instructorController = TextEditingController(
      text: existingItem?['instructor'] ?? existingItem?['professor'] ?? '',
    );

    List<CourseScheduleItem> schedules = [];
    final String rawTimeSlot = existingItem?['time_slot'] ??
        existingItem?['schedule'] ??
        existingItem?['time'] ??
        '';

    if (rawTimeSlot.isNotEmpty) {
      final slotParts = rawTimeSlot.split(', ');
      for (var slot in slotParts) {
        schedules.add(CourseScheduleItem.fromSlotString(slot));
      }
    }

    if (schedules.isEmpty) {
      schedules.add(CourseScheduleItem(
        day: defaultDay,
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 10, minute: 30),
      ));
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              title: Text(
                existingItem == null ? '✏️ 수강 과목 추가' : '✏️ 수강 과목 수정',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: '과목명',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: instructorController,
                        decoration: InputDecoration(
                          labelText: '교수님 성함',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildScheduleEditor(schedules, setDialogState),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                if (existingItem != null)
                  TextButton(
                    onPressed: () async {
                      final String targetTitle = existingItem['title'] ?? '';
                      final subjects =
                          context.read<SubjectProvider>().subjects;
                      final targetSub = subjects.firstWhere(
                        (s) => (s['title'] ?? s['name']) == targetTitle,
                        orElse: () => null,
                      );

                      if (targetSub != null) {
                        final int subId =
                            int.tryParse(targetSub['id'].toString()) ?? 0;
                        await context
                            .read<SubjectProvider>()
                            .deleteSubject(subId);
                      }
                      if (mounted) Navigator.pop(context);
                    },
                    child:
                        const Text('삭제', style: TextStyle(color: Colors.red)),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('과목명을 입력해주세요.')),
                      );
                      return;
                    }

                    final String title = titleController.text.trim();
                    final String instructor =
                        instructorController.text.trim().isEmpty
                            ? '미지정'
                            : instructorController.text.trim();

                    final String timeSlot =
                        schedules.map((s) => s.toSlotString()).join(', ');
                    final provider = context.read<SubjectProvider>();

                    if (existingItem != null) {
                      final targetSub = provider.subjects.firstWhere(
                        (s) =>
                            (s['title'] ?? s['name']) ==
                            (existingItem['title'] ?? ''),
                        orElse: () => null,
                      );
                      if (targetSub != null) {
                        final int subId =
                            int.tryParse(targetSub['id'].toString()) ?? 0;
                        await provider.updateSubject(
                            subId, title, instructor, timeSlot);
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
    final subjects = provider.subjects;

    final Map<String, List<Map<String, dynamic>>> parsedTimetable = {
      '월': [],
      '화': [],
      '수': [],
      '목': [],
      '금': [],
      '토': []
    };

    for (var sub in subjects) {
      final String title = sub['title'] ?? sub['name'] ?? '';
      final String instructor = sub['instructor'] ?? sub['professor'] ?? '';
      final String rawSlot =
          sub['time_slot'] ?? sub['schedule'] ?? sub['time'] ?? '';

      if (rawSlot.isNotEmpty) {
        final slots = rawSlot.split(',');
        for (var slot in slots) {
          final item = CourseScheduleItem.fromSlotString(slot.trim());
          if (parsedTimetable.containsKey(item.day)) {
            final startStr =
                '${item.startTime.hour.toString().padLeft(2, '0')}:${item.startTime.minute.toString().padLeft(2, '0')}';
            final endStr =
                '${item.endTime.hour.toString().padLeft(2, '0')}:${item.endTime.minute.toString().padLeft(2, '0')}';

            parsedTimetable[item.day]!.add({
              'title': title,
              'instructor': instructor,
              'room': item.room,
              'start_time': startStr,
              'end_time': endStr,
              'raw_item': sub,
            });
          }
        }
      }
    }

    const double rowHeight = 60.0;
    const int startHour = 9;

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('주간 시간표', style: TextStyle(fontWeight: FontWeight.bold)),
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
                const SizedBox(
                    width: 45,
                    child: Center(
                        child: Text('시간',
                            style:
                                TextStyle(fontSize: 12, color: Colors.grey)))),
                ..._days.map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
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
                              bottom: BorderSide(
                                  color: Colors.grey.shade300, width: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 45,
                                child: Center(
                                  child: Text(
                                    '$hour시',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey),
                                  ),
                                ),
                              ),
                              ..._days.map((_) => Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border(
                                          left: BorderSide(
                                              color: Colors.grey.shade200,
                                              width: 0.5),
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
                          final dayClasses = parsedTimetable[day] ?? [];
                          return Expanded(
                            child: Stack(
                              children: dayClasses.map((item) {
                                int startMin =
                                    _timeToMinutes(item['start_time']);
                                int endMin = _timeToMinutes(item['end_time']);

                                double topPosition =
                                    ((startMin - (startHour * 60)) / 60.0) *
                                        rowHeight;
                                double tileHeight =
                                    ((endMin - startMin) / 60.0) * rowHeight;
                                if (tileHeight < 30) tileHeight = 30;

                                final String title = item['title'] ?? '';
                                final subjectIndex = subjects.indexWhere(
                                  (s) => (s['title'] ?? s['name']) == title,
                                );

                                Color tileColor = Colors.indigo.shade100;
                                if (subjectIndex != -1) {
                                  tileColor = _cardColors[
                                      subjectIndex % _cardColors.length];
                                } else {
                                  int charSum = 0;
                                  for (int codeUnit in title.codeUnits) {
                                    charSum += codeUnit;
                                  }
                                  tileColor = _cardColors[
                                      charSum % _cardColors.length];
                                }

                                final String room = item['room'] ?? '';

                                return Positioned(
                                  top: topPosition + 1,
                                  left: 1,
                                  right: 1,
                                  height: tileHeight - 2,
                                  child: GestureDetector(
                                    onTap: () => _showAddOrEditClassDialog(
                                      defaultDay: day,
                                      existingItem: item['raw_item'],
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(4.0),
                                      decoration: BoxDecoration(
                                        color: tileColor,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black12,
                                            blurRadius: 2,
                                            offset: Offset(0, 1),
                                          )
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (tileHeight > 40) ...[
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
                                            if (room.isNotEmpty) ...[
                                              const SizedBox(height: 1),
                                              Text(
                                                room,
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  color: Colors.indigo,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
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