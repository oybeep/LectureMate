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
  TextEditingController roomController;

  CourseScheduleItem({
    required this.day,
    required this.startTime,
    required this.endTime,
    this.room = '',
  }) : roomController = TextEditingController(text: room) {
    roomController.addListener(() {
      room = roomController.text;
    });
  }

  void dispose() {
    roomController.dispose();
  }

  String toSlotString() {
    final startStr =
        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    final endStr =
        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    final currentRoom = roomController.text.trim();
    final roomStr = currentRoom.isNotEmpty ? ' ($currentRoom)' : '';
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
  final List<int> _hours = List.generate(15, (index) => index + 9); // 9시~23시

  // 다크 모드 / 라이트 모드 공용 파스텔 컬러 팔레트
  final List<Color> _cardColors = [
    Colors.indigo.shade200,
    Colors.teal.shade200,
    Colors.orange.shade200,
    Colors.purple.shade200,
    Colors.blue.shade200,
    Colors.pink.shade200,
    Colors.amber.shade200,
    Colors.lightGreen.shade200,
    Colors.cyan.shade200,
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

  int _timeOfDayToMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  String? _validateSchedules(
    List<CourseScheduleItem> schedules,
    List<dynamic> allSubjects, {
    int? currentEditingSubjectId,
  }) {
    for (int i = 0; i < schedules.length; i++) {
      final item = schedules[i];
      final startMin = _timeOfDayToMinutes(item.startTime);
      final endMin = _timeOfDayToMinutes(item.endTime);

      if (startMin >= endMin) {
        return '${item.day}요일의 종료 시간은 시작 시간보다 늦어야 합니다.';
      }
    }

    for (int i = 0; i < schedules.length; i++) {
      for (int j = i + 1; j < schedules.length; j++) {
        if (schedules[i].day == schedules[j].day) {
          final s1 = _timeOfDayToMinutes(schedules[i].startTime);
          final e1 = _timeOfDayToMinutes(schedules[i].endTime);
          final s2 = _timeOfDayToMinutes(schedules[j].startTime);
          final e2 = _timeOfDayToMinutes(schedules[j].endTime);

          if (s1 < e2 && e1 > s2) {
            return '입력한 일정 중 ${schedules[i].day}요일 일정이 서로 겹칩니다.';
          }
        }
      }
    }

    for (final newSch in schedules) {
      final newStart = _timeOfDayToMinutes(newSch.startTime);
      final newEnd = _timeOfDayToMinutes(newSch.endTime);

      for (final sub in allSubjects) {
        final int subId = int.tryParse(sub['id']?.toString() ?? '') ?? 0;
        if (currentEditingSubjectId != null && subId == currentEditingSubjectId) {
          continue;
        }

        final String existingSlotStr =
            sub['time_slot'] ?? sub['schedule'] ?? sub['time'] ?? '';
        final slots = existingSlotStr.split(',');

        for (final slot in slots) {
          final match = RegExp(r'([월화수목금토일])\s*(\d{2}:\d{2})~(\d{2}:\d{2})')
              .firstMatch(slot.trim());
          if (match != null) {
            final existDay = match.group(1);
            final existStart = _timeToMinutes(match.group(2)!);
            final existEnd = _timeToMinutes(match.group(3)!);

            if (existDay == newSch.day) {
              if (newStart < existEnd && newEnd > existStart) {
                final subName = sub['title'] ?? sub['name'] ?? '다른 과목';
                return '해당 시간에 이미 수업이 등록되어 있습니다.\n($subName: $existDay ${match.group(2)}~${match.group(3)})';
              }
            }
          }
        }
      }
    }

    return null;
  }

  Widget _buildScheduleEditor(
    List<CourseScheduleItem> schedules,
    StateSetter setDialogState,
    ThemeData theme,
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
            Text('수업 일정 목록',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: theme.colorScheme.onSurface)),
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
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: theme.dividerColor),
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
                        dropdownColor: theme.cardColor,
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
                          onPressed: () {
                            setDialogState(() {
                              final removed = schedules.removeAt(idx);
                              removed.dispose();
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: item.roomController,
                    decoration: const InputDecoration(
                      hintText: '강의실 (예: E동 513호)',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(),
                    ),
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
      final slotParts = rawTimeSlot.split(',');
      for (var slot in slotParts) {
        schedules.add(CourseScheduleItem.fromSlotString(slot.trim()));
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
        final theme = Theme.of(context);
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
                      _buildScheduleEditor(schedules, setDialogState, theme),
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
                      for (var item in schedules) {
                        item.dispose();
                      }
                      titleController.dispose();
                      instructorController.dispose();
                      if (mounted) Navigator.pop(context);
                    },
                    child:
                        const Text('삭제', style: TextStyle(color: Colors.red)),
                  ),
                TextButton(
                  onPressed: () {
                    for (var item in schedules) {
                      item.dispose();
                    }
                    titleController.dispose();
                    instructorController.dispose();
                    Navigator.pop(context);
                  },
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

                    final provider = context.read<SubjectProvider>();
                    final int? currentEditingId = existingItem != null
                        ? int.tryParse(existingItem['id']?.toString() ?? '')
                        : null;

                    final validationError = _validateSchedules(
                      schedules,
                      provider.subjects,
                      currentEditingSubjectId: currentEditingId,
                    );

                    if (validationError != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(validationError),
                          backgroundColor: Colors.redAccent,
                          duration: const Duration(seconds: 3),
                        ),
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

                    for (var item in schedules) {
                      item.dispose();
                    }
                    titleController.dispose();
                    instructorController.dispose();
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
    final theme = Theme.of(context);
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
        backgroundColor: theme.colorScheme.inversePrimary,
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
            color: theme.colorScheme.surfaceVariant,
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                SizedBox(
                    width: 45,
                    child: Center(
                        child: Text('시간',
                            style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant)))),
                ..._days.map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: theme.colorScheme.onSurface),
                        ),
                      ),
                    )),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: theme.dividerColor),
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
                                  color: theme.dividerColor.withOpacity(0.5),
                                  width: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 45,
                                child: Center(
                                  child: Text(
                                    '$hour시',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                ),
                              ),
                              ..._days.map((_) => Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border(
                                          left: BorderSide(
                                              color: theme.dividerColor
                                                  .withOpacity(0.3),
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

                                Color tileColor = Colors.indigo.shade200;
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
                                final String instructor =
                                    item['instructor'] ?? '';

                                return Positioned(
                                  top: topPosition + 1,
                                  left: 1,
                                  right: 1,
                                  height: tileHeight - 2,
                                  child: GestureDetector(
                                    onTap: () {
                                      _showAddOrEditClassDialog(
                                        defaultDay: day,
                                        existingItem: item['raw_item'],
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4.0),
                                      decoration: BoxDecoration(
                                        color: tileColor,
                                        borderRadius: BorderRadius.circular(6),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.08),
                                            blurRadius: 2,
                                            offset: const Offset(0, 1),
                                          )
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
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
                                          if (room.isNotEmpty)
                                            Text(
                                              room,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.black54,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          if (instructor.isNotEmpty &&
                                              instructor != '미지정')
                                            Text(
                                              instructor,
                                              style: const TextStyle(
                                                fontSize: 9,
                                                color: Colors.black45,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
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