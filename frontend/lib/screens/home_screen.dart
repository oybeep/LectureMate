import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String baseUrl = 'http://127.0.0.1:8000'; // 백엔드 서버 주소

  // 상태 변수
  String serverStatus = '서버 연결 확인 중...';
  List<dynamic> subjects = [];
  int? selectedSubjectId;

  List<dynamic> lectureNotes = [];
  bool isLoadingNotes = false;

  bool isRecording = false;
  bool isPaused = false; // ⏸️ 일시정지 상태 변수
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

  // ---------------------------------------------------------------------------
  // 🗓️ 시간표(SharedPreferences) 연동 헬퍼 메서드들
  // ---------------------------------------------------------------------------
  
  Future<void> _syncSubjectToTimetable(String title, String professor, String timeSlot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedData = prefs.getString('user_timetable');

      Map<String, List<Map<String, String>>> timetable = {
        '월': [], '화': [], '수': [], '목': [], '금': [],
      };

      if (savedData != null) {
        final Map<String, dynamic> decoded = jsonDecode(savedData);
        timetable = decoded.map((key, value) {
          final list = (value as List).map((item) => Map<String, String>.from(item)).toList();
          return MapEntry(key, list);
        });
      }

      final parts = timeSlot.split(' ');
      if (parts.length >= 2) {
        String day = parts[0];
        final times = parts[1].split('~');

        if (timetable.containsKey(day) && times.length == 2) {
          String startTime = times[0];
          String endTime = times[1];

          for (var key in timetable.keys) {
            timetable[key]!.removeWhere((item) => item['title'] == title);
          }

          timetable[day]!.add({
            'title': title,
            'instructor': professor.isEmpty ? '미지정' : professor,
            'start_time': startTime,
            'end_time': endTime,
            'time': '$startTime ~ $endTime',
          });

          await prefs.setString('user_timetable', jsonEncode(timetable));
        }
      }
    } catch (e) {
      debugPrint('시간표 동기화 에러: $e');
    }
  }

  Future<void> _deleteSubjectFromTimetable(String title) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedData = prefs.getString('user_timetable');

      if (savedData != null) {
        final Map<String, dynamic> decoded = jsonDecode(savedData);
        Map<String, List<Map<String, String>>> timetable = decoded.map((key, value) {
          final list = (value as List).map((item) => Map<String, String>.from(item)).toList();
          return MapEntry(key, list);
        });

        for (var day in timetable.keys) {
          timetable[day]!.removeWhere((item) => item['title'] == title);
        }

        await prefs.setString('user_timetable', jsonEncode(timetable));
      }
    } catch (e) {
      debugPrint('시간표 삭제 동기화 에러: $e');
    }
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

  // API 네트워크 통신 메서드들
  Future<void> _checkServerStatus() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health')).timeout(const Duration(seconds: 5));
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
      final response = await http.get(Uri.parse('$baseUrl/subjects/'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          subjects = data;
        });
      }
    } catch (e) {
      _showFeedbackSnackBar('과목 목록 불러오기 실패: $e', isError: true);
    }
  }

  Future<void> _fetchNotesForSubject(int subjectId) async {
    setState(() {
      isLoadingNotes = true;
    });
    try {
      final response = await http.get(Uri.parse('$baseUrl/lectures/subject/$subjectId'));
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

  Future<void> _addNewSubject(String title, String professor, String timeSlot) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/subjects/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': title,
          'professor': professor,
          'time_slot': timeSlot,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await _syncSubjectToTimetable(title, professor, timeSlot);
        _showFeedbackSnackBar('✨ 새 과목이 등록되었으며 시간표에 추가되었습니다!');
        _fetchSubjects();
      }
    } catch (e) {
      _showFeedbackSnackBar('과목 등록 실패: $e', isError: true);
    }
  }

  Future<void> _updateSubject(int subjectId, String title, String professor, String timeSlot) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/subjects/$subjectId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': title,
          'professor': professor,
          'time_slot': timeSlot,
        }),
      );
      if (response.statusCode == 200) {
        await _syncSubjectToTimetable(title, professor, timeSlot);
        _showFeedbackSnackBar('✨ 과목 정보 및 시간표가 수정되었습니다!');
        _fetchSubjects();
      }
    } catch (e) {
      _showFeedbackSnackBar('과목 수정 실패: $e', isError: true);
    }
  }

  Future<void> _deleteSubject(int subjectId, String title) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/subjects/$subjectId'));
      if (response.statusCode == 200) {
        await _deleteSubjectFromTimetable(title);
        _showFeedbackSnackBar('과목($title)이 삭제되었습니다.');
        if (selectedSubjectId == subjectId) {
          setState(() {
            selectedSubjectId = null;
            lectureNotes = [];
          });
        }
        _fetchSubjects();
      }
    } catch (e) {
      _showFeedbackSnackBar('과목 삭제 실패: $e', isError: true);
    }
  }

  Future<void> _showEditTitleDialog(int noteId, String currentTitle) async {
    final controller = TextEditingController(text: currentTitle);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('노트 제목 수정'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '새 제목'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('수정'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && selectedSubjectId != null) {
      try {
        final response = await http.patch(
          Uri.parse('$baseUrl/lectures/$noteId'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'title': result}),
        );
        if (response.statusCode == 200) {
          _showFeedbackSnackBar('노트 제목이 수정되었습니다.');
          _fetchNotesForSubject(selectedSubjectId!);
        }
      } catch (e) {
        _showFeedbackSnackBar('제목 수정 실패: $e', isError: true);
      }
    }
  }

  void _showAddSubjectDialog(BuildContext context) async {
    final titleController = TextEditingController();
    final professorController = TextEditingController();

    String selectedDay = '월';
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 30);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickTime(bool isStart) async {
              final picked = await showTimePicker(
                context: context,
                initialTime: isStart ? startTime : endTime,
              );
              if (picked != null) {
                setDialogState(() {
                  if (isStart) {
                    startTime = picked;
                  } else {
                    endTime = picked;
                  }
                });
              }
            }

            String formatTime(TimeOfDay t) {
              final hour = t.hour.toString().padLeft(2, '0');
              final minute = t.minute.toString().padLeft(2, '0');
              return '$hour:$minute';
            }

            return AlertDialog(
              title: const Text('✨ 새 수강 과목 추가', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: '과목명',
                          hintText: '예: 인공지능학',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: professorController,
                        decoration: const InputDecoration(
                          labelText: '교수님 성함',
                          hintText: '예: 김교수',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('강의 요일', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: ['월', '화', '수', '목', '금'].map((day) {
                          final isSelected = selectedDay == day;
                          return ChoiceChip(
                            label: Text(day),
                            selected: isSelected,
                            onSelected: (selected) {
                              setDialogState(() {
                                selectedDay = day;
                              });
                            },
                            selectedColor: Colors.indigo.shade100,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      const Text('강의 시간', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => pickTime(true),
                              icon: const Icon(Icons.access_time, size: 16),
                              label: Text(formatTime(startTime)),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text('~'),
                          ),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => pickTime(false),
                              icon: const Icon(Icons.access_time, size: 16),
                              label: Text(formatTime(endTime)),
                            ),
                          ),
                        ],
                      ),
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
                    if (subName.isEmpty) return;

                    final finalTimeSlot = '$selectedDay ${formatTime(startTime)}~${formatTime(endTime)}';

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

  void _showEditSubjectDialog(Map<String, dynamic> subject) async {
    final titleController = TextEditingController(text: subject['title'] ?? subject['name'] ?? '');
    final professorController = TextEditingController(text: subject['instructor'] ?? subject['professor'] ?? '');

    String selectedDay = '월';
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 30);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickTime(bool isStart) async {
              final picked = await showTimePicker(
                context: context,
                initialTime: isStart ? startTime : endTime,
              );
              if (picked != null) {
                setDialogState(() {
                  if (isStart) {
                    startTime = picked;
                  } else {
                    endTime = picked;
                  }
                });
              }
            }

            String formatTime(TimeOfDay t) {
              final hour = t.hour.toString().padLeft(2, '0');
              final minute = t.minute.toString().padLeft(2, '0');
              return '$hour:$minute';
            }

            return AlertDialog(
              title: const Text('✏️ 수강 과목 수정', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 400,
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
                      const SizedBox(height: 16),
                      TextField(
                        controller: professorController,
                        decoration: const InputDecoration(
                          labelText: '교수님 성함',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('강의 요일', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: ['월', '화', '수', '목', '금'].map((day) {
                          final isSelected = selectedDay == day;
                          return ChoiceChip(
                            label: Text(day),
                            selected: isSelected,
                            onSelected: (selected) {
                              setDialogState(() {
                                selectedDay = day;
                              });
                            },
                            selectedColor: Colors.indigo.shade100,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      const Text('강의 시간', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => pickTime(true),
                              icon: const Icon(Icons.access_time, size: 16),
                              label: Text(formatTime(startTime)),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text('~'),
                          ),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => pickTime(false),
                              icon: const Icon(Icons.access_time, size: 16),
                              label: Text(formatTime(endTime)),
                            ),
                          ),
                        ],
                      ),
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
                    if (subName.isEmpty) return;

                    final finalTimeSlot = '$selectedDay ${formatTime(startTime)}~${formatTime(endTime)}';

                    Navigator.pop(context, {
                      'title': subName,
                      'professor': profName,
                      'time_slot': finalTimeSlot,
                    });
                  },
                  child: const Text('수정'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      final int subId = int.parse(subject['id'].toString());
      await _updateSubject(
        subId,
        result['title'] ?? '',
        result['professor'] ?? '',
        result['time_slot'] ?? '',
      );
    }
  }

  Future<void> _uploadAudioFile() async {
    if (selectedSubjectId == null) {
      _showFeedbackSnackBar('먼저 수강 과목을 선택해 주세요.', isError: true);
      return;
    }

    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'mp4'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      _processAudioPipeline(result.files.single.bytes!, result.files.single.name);
    }
  }

  // 🎙️ 녹음 시작 및 완전 중지
  Future<void> _toggleRecording() async {
    if (selectedSubjectId == null) {
      _showFeedbackSnackBar('먼저 수강 과목을 선택해 주세요.', isError: true);
      return;
    }

    try {
      if (isRecording) {
        _stopTimer();
        final path = await _audioRecorder.stop();

        setState(() {
          isRecording = false;
          isPaused = false;
          processStatus = '녹음 완료! 백엔드 AI 분석 요청 중...';
        });

        if (path != null) {
          final response = await http.get(Uri.parse(path));
          await _processAudioPipeline(response.bodyBytes, 'lecture_recorded_${DateTime.now().millisecondsSinceEpoch}.m4a');
        }
      } else {
        if (await _audioRecorder.hasPermission()) {
          await _audioRecorder.start(
            const RecordConfig(encoder: AudioEncoder.aacLc),
            path: '',
          );
          _startTimer();
          setState(() {
            isRecording = true;
            isPaused = false;
            processStatus = '🎙️ 실시간 강의 녹음 진행 중...';
          });
        } else {
          _showFeedbackSnackBar('마이크 접근 권한이 필요합니다.', isError: true);
        }
      }
    } catch (e) {
      _stopTimer();
      _showFeedbackSnackBar('녹음 중 에러가 발생했습니다: $e', isError: true);
      setState(() {
        isRecording = false;
        isPaused = false;
      });
    }
  }

  // ⏸️ 녹음 일시정지 / 다시 시작 토글
  Future<void> _togglePauseRecording() async {
    if (!isRecording) return;

    try {
      if (isPaused) {
        await _audioRecorder.resume();
        setState(() {
          isPaused = false;
          processStatus = '🎙️ 실시간 강의 녹음 진행 중...';
        });
      } else {
        await _audioRecorder.pause();
        setState(() {
          isPaused = true;
          processStatus = '⏸️ 녹음 일시정지됨';
        });
      }
    } catch (e) {
      _showFeedbackSnackBar('녹음 일시정지 제어 에러: $e', isError: true);
    }
  }

  Future<void> _processAudioPipeline(List<int> bytes, String fileName) async {
    setState(() {
      isProcessing = true;
      latestNoteData = null;
      processStatus = '서버 전송 및 STT / AI 요약 / 퀴즈 생성 진행 중...';
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/lectures/upload'));
      request.fields['subject_id'] = selectedSubjectId.toString();
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

      var streamedResponse = await request.send().timeout(const Duration(minutes: 3));
      var response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        var resData = jsonDecode(utf8.decode(response.bodyBytes));

        final createdNote = {
          'id': resData['id'] ?? resData['lecture_id'],
          'title': resData['title'] ?? fileName,
          'summary': resData['summary'] ?? resData['message'] ?? '요약 결과가 없습니다.',
          'transcript': resData['transcript'] ?? resData['stt_transcript'] ?? 'STT 음성 변환 기록이 없습니다.',
          'keywords': resData['keywords'] ?? resData['key_concepts'] ?? ['강의 핵심', 'AI 분석'],
          'quizzes': resData['quizzes'] ?? resData['quiz'] ?? [],
        };

        setState(() {
          processStatus = '✨ AI 요약 및 퀴즈 생성 완료!';
          latestNoteData = createdNote;
        });

        _showFeedbackSnackBar('✨ 새로운 AI 요약 노트와 퀴즈가 생성되었습니다!');

        if (selectedSubjectId != null) {
          await _fetchNotesForSubject(selectedSubjectId!);
        }
      } else {
        _showFeedbackSnackBar('AI 분석 실패 (응답 코드: ${response.statusCode})', isError: true);
        setState(() {
          processStatus = '분석 실패 (응답 코드: ${response.statusCode})';
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showFeedbackSnackBar('AI 분석 중 통신 오류가 발생했습니다.', isError: true);
      setState(() {
        processStatus = '분석 에러 발생: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  void _showNoteDetailModal(Map<String, dynamic> note) {
    final String title = note['title'] ?? note['filename'] ?? '강의 요약 노트';
    final String summary = note['summary'] ?? '요약 내용이 없습니다.';
    final String transcript = note['transcript'] ?? note['stt_transcript'] ?? 'STT 음성 변환 기록이 없습니다.';

    List<dynamic> keywords = [];
    if (note['keywords'] is List) {
      keywords = note['keywords'];
    } else if (note['key_concepts'] is List) {
      keywords = note['key_concepts'];
    }

    List<dynamic> quizzes = [];
    if (note['quizzes'] is List) {
      quizzes = note['quizzes'];
    } else if (note['quiz'] is List) {
      quizzes = note['quiz'];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DefaultTabController(
          length: 3,
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder: (context, scrollController) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
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
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const TabBar(
                      labelColor: Colors.indigo,
                      indicatorColor: Colors.indigo,
                      tabs: [
                        Tab(icon: Icon(Icons.auto_awesome), text: "AI 요약"),
                        Tab(icon: Icon(Icons.quiz), text: "복습 퀴즈"),
                        Tab(icon: Icon(Icons.subtitles), text: "STT 원문"),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: TabBarView(
                        children: [
                          ListView(
                            controller: scrollController,
                            children: [
                              const SizedBox(height: 8),
                              const Text(
                                '🔑 핵심 키워드',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.indigo),
                              ),
                              const SizedBox(height: 8),
                              keywords.isEmpty
                                  ? const Text('추출된 키워드가 없습니다.', style: TextStyle(color: Colors.grey))
                                  : Wrap(
                                      spacing: 8.0,
                                      children: keywords.map<Widget>((kw) {
                                        return Chip(
                                          label: Text('# $kw'),
                                          backgroundColor: Colors.indigo.shade50,
                                          side: BorderSide.none,
                                        );
                                      }).toList(),
                                    ),
                              const Divider(height: 28),
                              const Text(
                                '📝 핵심 요약 노트',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.indigo),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.indigo.shade100),
                                ),
                                child: Text(
                                  summary,
                                  style: const TextStyle(fontSize: 15, height: 1.6),
                                ),
                              ),
                            ],
                          ),
                          quizzes.isEmpty
                              ? const Center(child: Text('생성된 AI 복습 퀴즈가 없습니다.'))
                              : ListView.builder(
                                  controller: scrollController,
                                  itemCount: quizzes.length,
                                  itemBuilder: (context, qIdx) {
                                    final quiz = quizzes[qIdx];
                                    return QuizCardWidget(quiz: quiz, index: qIdx);
                                  },
                                ),
                          ListView(
                            controller: scrollController,
                            children: [
                              const SizedBox(height: 8),
                              const Text(
                                '🎙️ 음성 변환(STT) 전체 텍스트',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.indigo),
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
                                  style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.black87),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.school, color: Colors.indigo),
            SizedBox(width: 8),
            Text('LectureMate MVP', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
            Card(
              elevation: 0,
              color: serverStatus.contains('실패') || serverStatus.contains('오류')
                  ? Colors.red.shade50
                  : Colors.green.shade50,
              child: ListTile(
                leading: Icon(
                  serverStatus.contains('실패') || serverStatus.contains('오류')
                      ? Icons.error_outline
                      : Icons.check_circle_outline,
                  color: serverStatus.contains('실패') || serverStatus.contains('오류')
                      ? Colors.red
                      : Colors.green,
                ),
                title: const Text('백엔드 서버 상태', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(serverStatus),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.indigo.shade50,
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.mic, color: Colors.indigo),
                            SizedBox(width: 8),
                            Text('강의 음성 분석', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
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
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: selectedSubjectId,
                      decoration: const InputDecoration(
                        labelText: '수강 과목 선택',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                      hint: const Text('분석할 과목을 선택하세요'),
                      items: subjects.map<DropdownMenuItem<int>>((dynamic subject) {
                        final int subId = int.parse(subject['id'].toString());
                        final String title = subject['title'] ?? subject['name'] ?? '과목';
                        final String prof = subject['instructor'] ?? subject['professor'] ?? '교수 미지정';
                        return DropdownMenuItem<int>(
                          value: subId,
                          child: Text('$title ($prof)'),
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
                      style: TextStyle(color: isRecording ? (isPaused ? Colors.orange.shade800 : Colors.red) : Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    if (isProcessing) ...[
                      const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 8),
                            Text('AI 파이프라인 진행 중 (STT ➔ 요약 ➔ 퀴즈)...'),
                          ],
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: (isRecording || selectedSubjectId == null) ? null : _uploadAudioFile,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('파일 업로드'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: selectedSubjectId == null ? null : _toggleRecording,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isRecording ? Colors.red : Colors.indigo,
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
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (latestNoteData != null) ...[
              Card(
                color: Colors.indigo.shade600,
                child: ListTile(
                  leading: const Icon(Icons.auto_awesome, color: Colors.white, size: 30),
                  title: const Text(
                    '✨ 방금 생성된 AI 노트 바로보기',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    '클릭하여 핵심 요약, 퀴즈, STT 원문 확인',
                    style: TextStyle(color: Colors.white70),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                  onTap: () => _showNoteDetailModal(latestNoteData!),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (selectedSubjectId != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('📚 과목 저장 노트', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: Text('해당 과목에 저장된 요약 노트가 없습니다.')),
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
                    final String noteTitle = note['title'] ?? note['filename'] ?? '강의 노트 ${index + 1}';

                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.article, color: Colors.indigo),
                        title: Text(noteTitle),
                        subtitle: Text(note['created_at'] ?? '저장됨'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.indigo, size: 20),
                              tooltip: '노트 제목 수정',
                              onPressed: () => _showEditTitleDialog(noteId, noteTitle),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () => _showNoteDetailModal(note),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 20),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('🗓️ 내 수강 과목 목록', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: () => _showAddSubjectDialog(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('과목 추가'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            subjects.isEmpty
                ? const Center(child: Text('등록된 과목이 없습니다. 과목 추가 버튼을 눌러보세요!'))
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
                        color: isSelected ? Colors.indigo.shade50 : null,
                        shape: isSelected
                            ? RoundedRectangleBorder(
                                side: const BorderSide(color: Colors.indigo, width: 1.5),
                                borderRadius: BorderRadius.circular(12),
                              )
                            : null,
                        child: ListTile(
                          leading: Icon(Icons.book, color: isSelected ? Colors.indigo : Colors.grey),
                          title: Text(
                            title,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text('$prof | ⏰ $time'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected)
                                const Padding(
                                  padding: EdgeInsets.only(right: 8.0),
                                  child: Chip(
                                    label: Text('선택됨', style: TextStyle(fontSize: 11, color: Colors.indigo)),
                                    backgroundColor: Colors.white,
                                    side: BorderSide(color: Colors.indigo),
                                  ),
                                ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Colors.indigo, size: 20),
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

// 퀴즈 전용 위젯
class QuizCardWidget extends StatefulWidget {
  final dynamic quiz;
  final int index;

  const QuizCardWidget({super.key, required this.quiz, required this.index});

  @override
  State<QuizCardWidget> createState() => _QuizCardWidgetState();
}

class _QuizCardWidgetState extends State<QuizCardWidget> {
  int? selectedOption;

  @override
  Widget build(BuildContext context) {
    final options = (widget.quiz['options'] ?? widget.quiz['choices'] ?? []) as List<dynamic>;
    final int correctAnswer = widget.quiz['answer'] ?? widget.quiz['correctIndex'] ?? 0;
    final String explanation = widget.quiz['explanation'] ?? '핵심 요약 내용을 참고하세요.';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Q${widget.index + 1}. ${widget.quiz['question'] ?? '문제'}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 10),
            ...options.asMap().entries.map((entry) {
              int optIdx = entry.key;
              String optText = entry.value.toString();

              bool isSelected = selectedOption == optIdx;
              bool isCorrect = optIdx == correctAnswer;

              Color? tileColor;
              if (selectedOption != null) {
                if (isCorrect) {
                  tileColor = Colors.green.shade50;
                } else if (isSelected) {
                  tileColor = Colors.red.shade50;
                }
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: tileColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  dense: true,
                  title: Text('${optIdx + 1}) $optText'),
                  leading: Icon(
                    selectedOption != null && isCorrect
                        ? Icons.check_circle
                        : (isSelected ? Icons.cancel : Icons.radio_button_unchecked),
                    color: selectedOption != null && isCorrect
                        ? Colors.green
                        : (isSelected ? Colors.red : Colors.grey),
                  ),
                  onTap: () {
                    setState(() {
                      selectedOption = optIdx;
                    });
                  },
                ),
              );
            }),
            if (selectedOption != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '💡 해설: $explanation',
                  style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}