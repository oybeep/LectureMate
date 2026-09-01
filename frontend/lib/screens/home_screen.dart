import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
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

  // time_slot 문자열 변환 (예: "화 09:30~11:00 (E동513호)")
  String toSlotString() {
    final startStr =
        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    final endStr =
        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    final roomStr = room.trim().isNotEmpty ? ' ($room)' : '';
    return '$day $startStr~$endStr$roomStr';
  }

  // "화 09:30~11:00 (E동513호)" 형태의 문자열 파싱
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String baseUrl = 'http://127.0.0.1:8000'; // 백엔드 서버 주소

  // 상태 변수
  String serverStatus = '서버 연결 확인 중...';
  int? selectedSubjectId;

  List<dynamic> lectureNotes = [];
  bool isLoadingNotes = false;

  bool isRecording = false;
  bool isPaused = false;
  bool isProcessing = false;
  String processStatus = '대기 중...';
  Map<String, dynamic>? latestNoteData;

  // 녹음 및 타이머 관련
  final AudioRecorder _audioRecorder = AudioRecorder();
  int _recordSeconds = 0;
  bool _timerActive = false;

  @override
  void initState() {
    super.initState();
    _checkServerStatus();
    _fetchSubjects();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  // Helper Methods
  void _startTimer() {
    _recordSeconds = 0;
    _timerActive = true;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!_timerActive) return false;
      if (mounted && isRecording && !isPaused) {
        setState(() {
          _recordSeconds++;
        });
      }
      return _timerActive;
    });
  }

  void _stopTimer() {
    _timerActive = false;
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  void _showFeedbackSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.indigo,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // API 네트워크 통신 메서드
  Future<void> _checkServerStatus() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        setState(() {
          serverStatus = '🟢 백엔드 서버가 정상 작동 중입니다.';
        });
      } else {
        setState(() {
          serverStatus = '🔴 서버 응답 이상 (코드: ${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        serverStatus = '🔴 백엔드 서버에 연결할 수 없습니다.';
      });
    }
  }

  Future<void> _fetchSubjects() async {
    try {
      await context.read<SubjectProvider>().fetchSubjects();
    } catch (e) {
      _showFeedbackSnackBar('과목 목록 불러오기 실패: $e', isError: true);
    }
  }

  Future<void> _fetchNotesForSubject(int subjectId) async {
    setState(() {
      isLoadingNotes = true;
    });
    try {
      final response =
          await http.get(Uri.parse('$baseUrl/lectures/subject/$subjectId'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          lectureNotes = data;
        });
      }
    } catch (e) {
      _showFeedbackSnackBar('노트 불러오기 실패: $e', isError: true);
    } finally {
      setState(() {
        isLoadingNotes = false;
      });
    }
  }

  // 1. 과목 추가
  Future<void> _addNewSubject(
      String title, String professor, String timeSlot) async {
    final bool success = await context
        .read<SubjectProvider>()
        .addSubject(title, professor, timeSlot);

    if (!mounted) return;

    if (success) {
      _showFeedbackSnackBar('✨ 새 과목이 등록되었으며 시간표에 추가되었습니다!');
    } else {
      _showFeedbackSnackBar('과목 등록 실패', isError: true);
    }
  }

  // 2. 과목 수정
  Future<void> _updateSubject(
      int subjectId, String title, String professor, String timeSlot) async {
    final success = await context
        .read<SubjectProvider>()
        .updateSubject(subjectId, title, professor, timeSlot);
    if (success) {
      _showFeedbackSnackBar('✨ 과목 정보 및 시간표가 수정되었습니다!');
    } else {
      _showFeedbackSnackBar('과목 수정 실패', isError: true);
    }
  }

  // 3. 과목 삭제
  Future<void> _deleteSubject(int subjectId, String title) async {
    final success =
        await context.read<SubjectProvider>().deleteSubject(subjectId);
    if (success) {
      _showFeedbackSnackBar('과목($title)이 삭제되었습니다.');
      if (selectedSubjectId == subjectId) {
        setState(() {
          selectedSubjectId = null;
          lectureNotes = [];
        });
      }
    } else {
      _showFeedbackSnackBar('과목 삭제 실패', isError: true);
    }
  }

  Future<void> _showEditTitleDialog(dynamic noteId, String currentTitle) async {
    final controller = TextEditingController(text: currentTitle);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('노트 제목 수정'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: '새 노트 제목',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && noteId != null) {
      try {
        final response = await http.patch(
          Uri.parse('$baseUrl/lectures/$noteId'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'title': result}),
        );

        if (response.statusCode == 200) {
          _showFeedbackSnackBar('노트 제목이 변경되었습니다.');

          if (selectedSubjectId != null) {
            _fetchNotesForSubject(selectedSubjectId!);
          }
        } else {
          _showFeedbackSnackBar('제목 수정 실패 (${response.statusCode})',
              isError: true);
        }
      } catch (e) { // 👈 이제 try-catch 짝이 정확히 맞아떨어집니다!
        _showFeedbackSnackBar('제목 수정 실패: $e', isError: true);
      }
    }
  }

  void _confirmDeleteNote(int noteId, String noteTitle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('노트 삭제'),
          ],
        ),
        content: Text("'$noteTitle' 노트를 삭제하시겠습니까?\n삭제 후에는 복구할 수 없습니다."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _deleteLectureNote(noteId);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteLectureNote(int noteId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/lectures/$noteId'),
      );

      if (response.statusCode == 200) {
        _showFeedbackSnackBar('노트가 삭제되었습니다.');

        if (selectedSubjectId != null) {
          await _fetchNotesForSubject(selectedSubjectId!);
        }
        setState(() {
          if (latestNoteData != null &&
              (latestNoteData!['id'] ?? latestNoteData!['lecture_id'])
                      .toString() ==
                  noteId.toString()) {
            latestNoteData = null;
          }
        });
      } else {
        _showFeedbackSnackBar('노트 삭제 실패 (${response.statusCode})',
            isError: true);
      }
    } catch (e) {
      _showFeedbackSnackBar('네트워크 오류로 노트를 삭제하지 못했습니다: $e', isError: true);
    }
  }

  // ---------------------------------------------------------------------------
  // 🗓️ 동적 시간표 리스트 다이얼로그 - 등록/수정 공통 위젯
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
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('시간 추가'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...schedules.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            color: Colors.grey.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10.0),
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
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8)),
                        onPressed: () => pickTime(item, true),
                        child: Text(formatTime(item.startTime)),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.0),
                        child: Text('~'),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8)),
                        onPressed: () => pickTime(item, false),
                        child: Text(formatTime(item.endTime)),
                      ),
                      const Spacer(),
                      if (schedules.length > 1)
                        IconButton(
                          icon: const Icon(Icons.remove_circle,
                              color: Colors.redAccent, size: 20),
                          onPressed: () =>
                              setDialogState(() => schedules.removeAt(idx)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: '강의실 (예: E동 513호)',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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

  // ---------------------------------------------------------------------------
  // ✨ 과목 추가 다이얼로그
  // ---------------------------------------------------------------------------
  void _showAddSubjectDialog(BuildContext context) async {
    final titleController = TextEditingController();
    final professorController = TextEditingController();

    List<CourseScheduleItem> schedules = [
      CourseScheduleItem(
        day: '월',
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 10, minute: 30),
      )
    ];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('✨ 새 수강 과목 추가',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: '과목명',
                          hintText: '예: 데이터시각화',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: professorController,
                        decoration: const InputDecoration(
                          labelText: '교수님 성함',
                          hintText: '예: 김교수',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildScheduleEditor(schedules, setDialogState),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('취소', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final subName = titleController.text.trim();
                    final profName = professorController.text.trim();
                    if (subName.isEmpty) {
                      _showFeedbackSnackBar('과목명을 입력해 주세요.', isError: true);
                      return;
                    }

                    // ✨ [검증] 시간 역전 및 중복 체크
                    final errorMsg = _validateSchedules(schedules);
                    if (errorMsg != null) {
                      _showFeedbackSnackBar(errorMsg, isError: true);
                      return; // 팝업 유지 & 등록 차단
                    }

                    final finalTimeSlot =
                        schedules.map((s) => s.toSlotString()).join(', ');

                    Navigator.pop(context, {
                      'title': subName,
                      'professor': profName,
                      'time_slot': finalTimeSlot,
                    });
                  },
                  child: const Text('등록'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      await _addNewSubject(
        result['title'] ?? '',
        result['professor'] ?? '',
        result['time_slot'] ?? '',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // ✏️ 과목 수정 다이얼로그
  // ---------------------------------------------------------------------------
  void _showEditSubjectDialog(dynamic subject) async {
    final int subId = int.parse(subject['id'].toString());
    final titleController = TextEditingController(
        text: subject['title'] ?? subject['name'] ?? '');
    final professorController = TextEditingController(
        text: subject['instructor'] ?? subject['professor'] ?? '');

    String existingSlot =
        subject['time_slot'] ?? subject['time'] ?? '월 09:00~10:30';
    List<String> slotStrings = existingSlot.split(', ');
    List<CourseScheduleItem> schedules =
        slotStrings.map((s) => CourseScheduleItem.fromSlotString(s)).toList();

    if (schedules.isEmpty) {
      schedules.add(CourseScheduleItem(
        day: '월',
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 10, minute: 30),
      ));
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('✏️ 과목 정보 수정',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: '과목명',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: professorController,
                        decoration: const InputDecoration(
                          labelText: '교수님 성함',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildScheduleEditor(schedules, setDialogState),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('취소', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final subName = titleController.text.trim();
                    final profName = professorController.text.trim();
                    if (subName.isEmpty) {
                      _showFeedbackSnackBar('과목명을 입력해 주세요.', isError: true);
                      return;
                    }

                    // ✨ [검증] 본인 과목 ID를 넘겨 자기 자신과의 중복은 제외하고 체크
                    final errorMsg = _validateSchedules(schedules, currentEditingSubjectId: subId);
                    if (errorMsg != null) {
                      _showFeedbackSnackBar(errorMsg, isError: true);
                      return; // 팝업 유지 & 수정 차단
                    }

                    final finalTimeSlot =
                        schedules.map((s) => s.toSlotString()).join(', ');

                    Navigator.pop(context, {
                      'title': subName,
                      'professor': profName,
                      'time_slot': finalTimeSlot,
                    });
                  },
                  child: const Text('수정 저장'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      await _updateSubject(
        subId,
        result['title'] ?? '',
        result['professor'] ?? '',
        result['time_slot'] ?? '',
      );
    }
  }

  int _timeOfDayToMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  int _stringTimeToMinutes(String timeStr) {
    final parts = timeStr.trim().split(':');
    if (parts.length < 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  String? _validateSchedules(List<CourseScheduleItem> schedules, {int? currentEditingSubjectId}) {
    // 시작/종료 시간 역전 검사 (2번 요구사항)
    for (int i = 0; i < schedules.length; i++) {
      final item = schedules[i];
      final startMin = _timeOfDayToMinutes(item.startTime);
      final endMin = _timeOfDayToMinutes(item.endTime);

      if (startMin >= endMin) {
        return '${item.day}요일 일정의 종료 시간이 시작 시간보다 같거나 빠릅니다.';
      }
    }

    // 한 과목 내에서 추가한 여러 일정 간의 중복 검사
    for (int i = 0; i < schedules.length; i++) {
      for (int j = i + 1; j < schedules.length; j++) {
        if (schedules[i].day == schedules[j].day) {
          final s1 = _timeOfDayToMinutes(schedules[i].startTime);
          final e1 = _timeOfDayToMinutes(schedules[i].endTime);
          final s2 = _timeOfDayToMinutes(schedules[j].startTime);
          final e2 = _timeOfDayToMinutes(schedules[j].endTime);

          if (s1 < e2 && e1 > s2) {
            return '입력하신 일정 중 ${schedules[i].day}요일 시간이 서로 겹칩니다.';
          }
        }
      }
    }

    // 기존 등록된 다른 과목들과의 중복 검사 
    final currentSubjects = context.read<SubjectProvider>().subjects;
    for (final newSch in schedules) {
      final newStart = _timeOfDayToMinutes(newSch.startTime);
      final newEnd = _timeOfDayToMinutes(newSch.endTime);

      for (final sub in currentSubjects) {
        final int subId = int.tryParse(sub['id']?.toString() ?? '') ?? 0;
        if (currentEditingSubjectId != null && subId == currentEditingSubjectId) {
          continue; // 수정 중인 과목 자신은 비교에서 제외
        }

        final String existingSlotStr = sub['time_slot'] ?? sub['time'] ?? '';
        final slots = existingSlotStr.split(', ');

        for (final slot in slots) {
          final match = RegExp(r'([월화수목금토일])\s*(\d{2}:\d{2})~(\d{2}:\d{2})').firstMatch(slot.trim());
          if (match != null) {
            final existDay = match.group(1);
            final existStart = _stringTimeToMinutes(match.group(2)!);
            final existEnd = _stringTimeToMinutes(match.group(3)!);

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

// ---------------------------------------------------------------------------
  // 🔍 [추가] 단건 노트 상세 조회 헬퍼 메서드
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>?> _fetchSingleNoteDetail(int noteId) async {
    try {
      // 백엔드 단건 조회 API 호출 (경로가 다를 경우 프로젝트에 맞게 수정)
      final response = await http.get(Uri.parse('$baseUrl/notes/$noteId'));
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
    } catch (e) {
      print("노트 상세 조회 중 오류 발생: $e");
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 🎙️ 음성 파일 업로드 및 녹음 제어 메서드
  // ---------------------------------------------------------------------------
  Future<void> _uploadAudioFile() async {
    if (selectedSubjectId == null) {
      _showFeedbackSnackBar('과목을 먼저 선택해 주세요.', isError: true);
      return;
    }

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'flac'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      final fileName = file.name;

      setState(() {
        isProcessing = true;
        processStatus = '음성 파일 전송 및 AI 분석 중...';
      });

      try {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/lectures/upload'),
        );
        request.fields['subject_id'] = selectedSubjectId.toString();
        request.fields['title'] = fileName;

        if (file.bytes != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              file.bytes!,
              filename: fileName,
            ),
          );
        } else if (file.path != null) {
          request.files.add(
            await http.MultipartFile.fromPath('file', file.path!),
          );
        }

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200 || response.statusCode == 201) {
          final resData = jsonDecode(utf8.decode(response.bodyBytes));
          
          // 1. 생성된 노트 ID 추출
          final int? noteId = resData['note_id'] ?? resData['id'];

          // 2. 전체 과목 노트 목록 새로고침
          await _fetchNotesForSubject(selectedSubjectId!);

          // 3. 최신 요약 정보가 담긴 단건 노트를 재조회하여 반영
          Map<String, dynamic>? fullNoteData;
          if (noteId != null) {
            fullNoteData = await _fetchSingleNoteDetail(noteId) ?? resData;
          } else {
            fullNoteData = resData;
          }

          setState(() {
            latestNoteData = fullNoteData; // 요약 데이터가 포함된 최신 객체 할당
            processStatus = '✨ AI 노트 생성 완료!';
          });

          _showFeedbackSnackBar('✨ AI 노트 생성이 완료되었습니다!');
        } else {
          setState(() {
            processStatus = '노트 생성 실패 (${response.statusCode})';
          });
          _showFeedbackSnackBar('파일 업로드 실패 (${response.statusCode})', isError: true);
        }
      } catch (e) {
        setState(() {
          processStatus = '오류 발생: $e';
        });
        _showFeedbackSnackBar('네트워크 오류: $e', isError: true);
      } finally {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  Future<void> _toggleRecording() async {
    if (selectedSubjectId == null) {
      _showFeedbackSnackBar('녹음할 과목을 먼저 선택해 주세요.', isError: true);
      return;
    }

    if (isRecording) {
      // 녹음 중지
      _stopTimer();
      final path = await _audioRecorder.stop();
      setState(() {
        isRecording = false;
        isPaused = false;
      });

      if (path != null) {
        // 녹음 파일 백엔드 전송
        setState(() {
          isProcessing = true;
          processStatus = '녹음 파일 분석 중...';
        });

        try {
          final request = http.MultipartRequest(
            'POST',
            Uri.parse('$baseUrl/lectures/upload'),
          );
          request.fields['subject_id'] = selectedSubjectId.toString();
          request.fields['title'] =
              '실시간 녹음 ${DateTime.now().toString().substring(0, 16)}';
          request.files.add(await http.MultipartFile.fromPath('file', path));

          final streamedResponse = await request.send();
          final response = await http.Response.fromStream(streamedResponse);

          if (response.statusCode == 200 || response.statusCode == 201) {
            final resData = jsonDecode(utf8.decode(response.bodyBytes));
            
            // 1. 생성된 노트 ID 추출
            final int? noteId = resData['note_id'] ?? resData['id'];

            // 2. 전체 과목 노트 목록 새로고침
            await _fetchNotesForSubject(selectedSubjectId!);

            // 3. 최신 요약 정보가 담긴 단건 노트를 재조회하여 반영
            Map<String, dynamic>? fullNoteData;
            if (noteId != null) {
              fullNoteData = await _fetchSingleNoteDetail(noteId) ?? resData;
            } else {
              fullNoteData = resData;
            }

            setState(() {
              latestNoteData = fullNoteData; // 요약 데이터가 포함된 최신 객체 할당
              processStatus = '✨ AI 노트 생성 완료!';
            });

            _showFeedbackSnackBar('✨ 녹음본 AI 노트 생성이 완료되었습니다!');
          } else {
            _showFeedbackSnackBar('녹음 분석 실패 (${response.statusCode})',
                isError: true);
          }
        } catch (e) {
          _showFeedbackSnackBar('녹음 처리 중 오류: $e', isError: true);
        } finally {
          setState(() {
            isProcessing = false;
          });
        }
      }
    } else {
      // 녹음 시작
      if (await _audioRecorder.hasPermission()) {
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: '',
        );
        setState(() {
          isRecording = true;
          isPaused = false;
          processStatus = '🎙️ 실시간 강의 음성 녹음 중...';
        });
        _startTimer();
      } else {
        _showFeedbackSnackBar('마이크 접근 권한이 필요합니다.', isError: true);
      }
    }
  }

  void _togglePauseRecording() async {
    if (!isRecording) return;

    if (isPaused) {
      await _audioRecorder.resume();
      setState(() {
        isPaused = false;
        processStatus = '🎙️ 실시간 강의 음성 녹음 중...';
      });
    } else {
      await _audioRecorder.pause();
      setState(() {
        isPaused = true;
        processStatus = '⏸️ 녹음이 일시정지되었습니다.';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // 📑 AI 상세 요약 모달 (📌 세부 강의 내용 포함)
  // ---------------------------------------------------------------------------
  void _showNoteDetailModal(Map<String, dynamic> note) {
    // 1. 중첩된 detail 객체가 있을 경우를 대비한 데이터 참조
    final Map<String, dynamic> data = (note['detail'] is Map<String, dynamic>)
        ? note['detail']
        : (note['data'] is Map<String, dynamic> ? note['data'] : note);

    final String title = note['title'] ?? note['filename'] ?? '강의 요약 노트';

    // 2. 핵심 요약 키값 유연화 (ai_summary, overview 등 추가)
    final String summary = (data['summary'] ??
            data['ai_summary'] ??
            data['overview'] ??
            note['summary'] ??
            '요약 내용이 없습니다.')
        .toString();

    // 3. STT 원문 키값 유연화
    final String transcript = (data['transcript'] ??
            data['stt_transcript'] ??
            note['transcript'] ??
            note['stt_transcript'] ??
            'STT 음성 변환 기록이 없습니다.')
        .toString();

    // 4. 키워드 추출 유연화 (List 혹은 Comma 구분 String 대응)
    List<dynamic> keywords = [];
    final rawKeywords = data['keywords'] ??
        data['key_concepts'] ??
        note['keywords'] ??
        note['key_concepts'];
    if (rawKeywords is List) {
      keywords = rawKeywords;
    } else if (rawKeywords is String && rawKeywords.isNotEmpty) {
      keywords = rawKeywords.split(',').map((e) => e.trim()).toList();
    }

    // 5. 세부 요약 항목 추출 (sections, contents 등 키값 추가 탐색)
    List<dynamic> detailedSummary = [];
    final rawDetails = data['detailed_summary'] ??
        data['detail_summary'] ??
        data['details'] ??
        data['bullet_points'] ??
        data['sections'] ??
        note['detailed_summary'] ??
        note['detail_summary'] ??
        note['details'] ??
        note['bullet_points'];

    if (rawDetails is List) {
      detailedSummary = rawDetails;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DefaultTabController(
          length: 2,
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder: (context, scrollController) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 12.0),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const TabBar(
                      labelColor: Colors.indigo,
                      indicatorColor: Colors.indigo,
                      tabs: [
                        Tab(icon: Icon(Icons.auto_awesome), text: "AI 요약"),
                        Tab(icon: Icon(Icons.subtitles), text: "STT 원문"),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // 1️⃣ AI 요약 탭
                          ListView(
                            controller: scrollController,
                            children: [
                              const SizedBox(height: 8),
                              const Text(
                                '🔑 핵심 키워드',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo),
                              ),
                              const SizedBox(height: 8),
                              keywords.isEmpty
                                  ? const Text('추출된 키워드가 없습니다.',
                                      style: TextStyle(color: Colors.grey))
                                  : Wrap(
                                      spacing: 8.0,
                                      children: keywords.map<Widget>((kw) {
                                        return Chip(
                                          label: Text('# $kw'),
                                          backgroundColor:
                                              Colors.indigo.shade50,
                                          side: BorderSide.none,
                                        );
                                      }).toList(),
                                    ),
                              const Divider(height: 28),
                              const Text(
                                '📝 핵심 요약 노트',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.indigo.shade100),
                                ),
                                child: Text(
                                  summary,
                                  style: const TextStyle(
                                      fontSize: 15, height: 1.6),
                                ),
                              ),
                              const Divider(height: 28),
                              const Text(
                                '📌 세부 강의 내용',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo),
                              ),
                              const SizedBox(height: 10),
                              detailedSummary.isEmpty
                                  ? Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        '세부 강의 내용이 없습니다.',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    )
                                  : Column(
                                      children: detailedSummary
                                          .asMap()
                                          .entries
                                          .map<Widget>((entry) {
                                        final int index = entry.key + 1;
                                        final item = entry.value;

                                        // 1️⃣ Map 형태 (title + points/subpoints 구조)
                                        if (item is Map) {
                                          final String subTitle =
                                              item['title'] ??
                                                  item['topic'] ??
                                                  '주제 $index';
                                          List<dynamic> points = [];
                                          if (item['points'] is List) {
                                            points = item['points'];
                                          } else if (item['descriptions']
                                              is List) {
                                            points = item['descriptions'];
                                          } else if (item['explanation'] !=
                                              null) {
                                            points = [
                                              item['explanation'].toString()
                                            ];
                                          }

                                          return Container(
                                            margin: const EdgeInsets.only(
                                                bottom: 12),
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: Colors.indigo.shade50
                                                  .withOpacity(0.4),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color:
                                                      Colors.indigo.shade100),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Icon(
                                                      Icons.check_circle_rounded,
                                                      size: 20,
                                                      color: Colors.indigo,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        '$index. $subTitle',
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.indigo,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (points.isNotEmpty) ...[
                                                  const SizedBox(height: 8),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 28.0),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: points
                                                          .map<Widget>((p) {
                                                        return Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  bottom: 4.0),
                                                          child: Row(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              const Text('• ',
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .black54,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold)),
                                                              Expanded(
                                                                child: Text(
                                                                  p.toString(),
                                                                  style: const TextStyle(
                                                                      fontSize:
                                                                          13.5,
                                                                      height:
                                                                          1.4,
                                                                      color: Colors
                                                                          .black87),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      }).toList(),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          );
                                        }

                                        // 2️⃣ 기존 단순 텍스트 형태 호환
                                        return Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.indigo.shade50
                                                .withOpacity(0.4),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                                color: Colors.indigo.shade100),
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Icon(
                                                Icons.check_circle_rounded,
                                                size: 18,
                                                color: Colors.indigo,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  '$index. ${item.toString()}',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    height: 1.5,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                              const SizedBox(height: 16),
                            ],
                          ),

                          // 2️⃣ STT 원문 탭
                          ListView(
                            controller: scrollController,
                            children: [
                              const SizedBox(height: 8),
                              const Text(
                                '🎙️ 음성 변환(STT) 전체 텍스트',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: SelectableText(
                                  transcript,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.6,
                                      color: Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

// ---------------------------------------------------------------------------
  // 🎨 메인 화면 UI 빌드 (다크모드 완벽 대응)
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final subjects = context.watch<SubjectProvider>().subjects;
    
    // 테마 및 색상 변수 정의
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.school, color: colorScheme.primary),
            const SizedBox(width: 8),
            const Text(
              'LectureMate MVP',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '서버 데이터 새로고침',
            onPressed: () => _fetchSubjects(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 백엔드 서버 상태 카드
            Card(
              elevation: 0,
              color: serverStatus.contains('실패') ||
                      serverStatus.contains('오류') ||
                      serverStatus.contains('없습니다')
                  ? (isDark ? Colors.red.shade900.withOpacity(0.4) : Colors.red.shade50)
                  : (isDark ? Colors.green.shade900.withOpacity(0.4) : Colors.green.shade50),
              child: ListTile(
                leading: Icon(
                  serverStatus.contains('실패') ||
                          serverStatus.contains('오류') ||
                          serverStatus.contains('없습니다')
                      ? Icons.error_outline
                      : Icons.check_circle_outline,
                  color: serverStatus.contains('실패') ||
                          serverStatus.contains('오류') ||
                          serverStatus.contains('없습니다')
                      ? Colors.red
                      : Colors.green,
                ),
                title: Text(
                  '백엔드 서버 상태',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  serverStatus,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. 실시간 음성 분석 / 파일 업로드 섹션 카드
            Card(
              color: isDark ? colorScheme.surfaceContainerHigh : Colors.indigo.shade50,
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.mic, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              '강의 음성 분석',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        if (isRecording)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isPaused ? Colors.orange : Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isPaused ? Icons.pause_circle_filled : Icons.fiber_manual_record,
                                  color: Colors.white,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isPaused ? '일시정지' : _formatDuration(_recordSeconds),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // 수강 과목 선택 드롭다운
                    DropdownButtonFormField<int>(
                      value: selectedSubjectId,
                      dropdownColor: theme.cardColor,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: '수강 과목 선택',
                        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        fillColor: isDark ? colorScheme.surface : Colors.white,
                        filled: true,
                      ),
                      hint: Text(
                        '분석할 과목을 선택하세요',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                      items: subjects.map<DropdownMenuItem<int>>((dynamic subject) {
                        final int subId = int.parse(subject['id'].toString());
                        final String title = subject['title'] ?? subject['name'] ?? '과목';
                        final String prof = subject['instructor'] ?? subject['professor'] ?? '교수 미지정';
                        return DropdownMenuItem<int>(
                          value: subId,
                          child: Text(
                            '$title ($prof)',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                        );
                      }).toList(),
                      onChanged: (isProcessing || isRecording)
                          ? null
                          : (int? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  selectedSubjectId = newValue;
                                  processStatus = '선택한 과목 노트 목록을 동기화합니다.';
                                });
                                _fetchNotesForSubject(newValue);
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      processStatus,
                      style: TextStyle(
                        color: isRecording
                            ? (isPaused ? Colors.orange.shade800 : Colors.red)
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isProcessing) ...[
                      const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 8),
                            Text('AI 파이프라인 진행 중 (STT ➔ AI 요약)...'),
                          ],
                        ),
                      ),
                    ] else ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: (isRecording || selectedSubjectId == null)
                                  ? null
                                  : _uploadAudioFile,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('파일 업로드'),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              onPressed: selectedSubjectId == null ? null : _toggleRecording,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isRecording ? Colors.red : colorScheme.primary,
                                foregroundColor: Colors.white,
                              ),
                              icon: Icon(isRecording ? Icons.stop : Icons.mic),
                              label: Text(isRecording ? '녹음 중지 및 분석' : '실시간 음성 녹음'),
                            ),
                            if (isRecording) ...[
                              const SizedBox(width: 10),
                              OutlinedButton.icon(
                                onPressed: _togglePauseRecording,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.orange.shade800,
                                  side: BorderSide(color: Colors.orange.shade800),
                                ),
                                icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                                label: Text(isPaused ? '다시 시작' : '일시정지'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 3. 방금 생성된 AI 노트 바로보기 카드
            if (latestNoteData != null) ...[
              Card(
                color: isDark ? colorScheme.primaryContainer : Colors.indigo.shade600,
                child: ListTile(
                  leading: const Icon(Icons.auto_awesome, color: Colors.white, size: 30),
                  title: const Text(
                    '✨ 방금 생성된 AI 노트 바로보기',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    '클릭하여 핵심 요약 및 STT 원문 확인',
                    style: TextStyle(color: Colors.white70),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                  onTap: () => _showNoteDetailModal(latestNoteData!),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 4. 선택 과목의 저장된 노트 목록
            if (selectedSubjectId != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '📚 과목 저장 노트',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: () => _fetchNotesForSubject(selectedSubjectId!),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (isLoadingNotes)
                const Center(child: CircularProgressIndicator())
              else if (lectureNotes.isEmpty)
                Card(
                  color: theme.cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        '해당 과목에 저장된 요약 노트가 없습니다.',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: lectureNotes.length,
                  itemBuilder: (context, index) {
                    final note = Map<String, dynamic>.from(lectureNotes[index]);
                    final int noteId = int.parse((note['id'] ?? note['lecture_id']).toString());
                    final String noteTitle =
                        note['title'] ?? note['filename'] ?? '강의 노트 ${index + 1}';

                    return Card(
                      color: theme.cardColor,
                      child: ListTile(
                        leading: Icon(Icons.article, color: colorScheme.primary),
                        title: Text(
                          noteTitle,
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                        subtitle: Text(
                          note['created_at'] ?? '저장됨',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit_outlined, color: colorScheme.primary, size: 20),
                              tooltip: '노트 제목 수정',
                              onPressed: () => _showEditTitleDialog(noteId, noteTitle),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              tooltip: '노트 삭제',
                              onPressed: () => _confirmDeleteNote(noteId, noteTitle),
                            ),
                            Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
                          ],
                        ),
                        onTap: () async {
                          final int targetId = int.parse(
                            (note['id'] ?? note['lecture_id'] ?? note['note_id']).toString(),
                          );
                          final fullNote = await _fetchSingleNoteDetail(targetId);
                          if (mounted) {
                            _showNoteDetailModal(fullNote ?? note);
                          }
                        },
                      ),
                    );
                  },
                ),
              const SizedBox(height: 20),
            ],

            // 5. 내 수강 과목 목록
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '🗓️ 내 수강 과목 목록',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddSubjectDialog(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('과목 추가'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            subjects.isEmpty
                ? Center(
                    child: Text(
                      '등록된 과목이 없습니다. 과목 추가 버튼을 눌러보세요!',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: subjects.length,
                    itemBuilder: (context, index) {
                      final subject = subjects[index];
                      final int subId = int.parse(subject['id'].toString());
                      final String title = subject['title'] ?? subject['name'] ?? '과목명';
                      final String prof = subject['instructor'] ?? subject['professor'] ?? '교수 미지정';
                      final String time = subject['time_slot'] ?? subject['time'] ?? '시간 미정';

                      bool isSelected = selectedSubjectId == subId;

                      return Card(
                        color: isSelected
                            ? (isDark
                                ? colorScheme.primaryContainer.withOpacity(0.4)
                                : Colors.indigo.shade50)
                            : theme.cardColor,
                        shape: isSelected
                            ? RoundedRectangleBorder(
                                side: BorderSide(color: colorScheme.primary, width: 1.5),
                                borderRadius: BorderRadius.circular(12),
                              )
                            : null,
                        child: ListTile(
                          leading: Icon(
                            Icons.book,
                            color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                          ),
                          title: Text(
                            title,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            '$prof | ⏰ $time',
                            style: TextStyle(color: colorScheme.onSurfaceVariant),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Chip(
                                    label: Text(
                                      '선택됨',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                    backgroundColor: theme.cardColor,
                                    side: BorderSide(color: colorScheme.primary),
                                  ),
                                ),
                              IconButton(
                                icon: Icon(Icons.edit_outlined, color: colorScheme.primary, size: 20),
                                tooltip: '과목 수정',
                                onPressed: () => _showEditSubjectDialog(subject),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                tooltip: '과목 삭제',
                                onPressed: () => _deleteSubject(subId, title),
                              ),
                            ],
                          ),
                          onTap: () {
                            setState(() {
                              selectedSubjectId = subId;
                              processStatus = '선택 과목: $title';
                            });
                            _fetchNotesForSubject(subId);
                          },
                        ),
                      );
                    },
                  ),
          ], 
        ),
      ),
    );
  }
}