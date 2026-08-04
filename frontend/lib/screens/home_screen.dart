import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'dart:convert';
import 'dart:async';
import '../main.dart'; // ApiConfig 참조

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String baseUrl = ApiConfig.baseUrl;

  String serverStatus = '서버 연결 확인 중...';
  List<dynamic> subjects = [];
  int? selectedSubjectId;

  List<dynamic> lectureNotes = [];
  bool isLoadingNotes = false;

  String processStatus = '수강 과목을 선택한 후 음성 파일 업로드 또는 직접 녹음을 진행해 주세요.';
  bool isProcessing = false;

  Map<String, dynamic>? latestNoteData;

  final AudioRecorder _audioRecorder = AudioRecorder();
  bool isRecording = false;
  Timer? _timer;
  int _recordSeconds = 0;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _startTimer() {
    _recordSeconds = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordSeconds++;
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  String _formatDuration(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showFeedbackSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.indigo.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> fetchData() async {
    try {
      final healthRes = await http.get(Uri.parse('$baseUrl/health')).timeout(const Duration(seconds: 5));
      final subjectsRes = await http.get(Uri.parse('$baseUrl/subjects')).timeout(const Duration(seconds: 5));

      if (healthRes.statusCode == 200 && subjectsRes.statusCode == 200) {
        setState(() {
          serverStatus = jsonDecode(healthRes.body)['message'];
          subjects = jsonDecode(utf8.decode(subjectsRes.bodyBytes));
        });
      } else {
        setState(() {
          serverStatus = '서버 응답 오류 (${healthRes.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        serverStatus = '서버 연결 실패 (네트워크를 확인하세요)';
      });
      _showFeedbackSnackBar('백엔드 서버에 연결할 수 없습니다. ($baseUrl)', isError: true);
    }
  }

  Future<void> addNewSubject(String title, String instructor, String timeSlot) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/subjects'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'title': title,
          'instructor': instructor,
          'time_slot': timeSlot,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showFeedbackSnackBar('새 수강 과목이 등록되었습니다!');
        fetchData();
      } else {
        _showFeedbackSnackBar('과목 등록 실패 (${response.statusCode})', isError: true);
      }
    } catch (e) {
      _showFeedbackSnackBar('네트워크 오류로 과목을 등록하지 못했습니다.', isError: true);
    }
  }

  void showAddSubjectDialog() {
    final titleController = TextEditingController();
    final instructorController = TextEditingController();
    final timeSlotController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.add_task, color: Colors.indigo),
              SizedBox(width: 8),
              Text('새 수강 과목 추가'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '과목명 (예: AI 인공지능학)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: instructorController,
                decoration: const InputDecoration(
                  labelText: '교수님 성함 (예: 김교수)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: timeSlotController,
                decoration: const InputDecoration(
                  labelText: '강의 시간 (예: 월 10:30~12:00)',
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
                if (titleController.text.trim().isNotEmpty) {
                  addNewSubject(
                    titleController.text.trim(),
                    instructorController.text.trim().isEmpty ? '미지정' : instructorController.text.trim(),
                    timeSlotController.text.trim().isEmpty ? '시간 미정' : timeSlotController.text.trim(),
                  );
                  Navigator.pop(context);
                } else {
                  _showFeedbackSnackBar('과목명을 입력해 주세요.', isError: true);
                }
              },
              child: const Text('등록'),
            ),
          ],
        );
      },
    );
  }

  Future<void> fetchLectures(int subjectId) async {
    setState(() {
      isLoadingNotes = true;
    });

    try {
      final res = await http.get(Uri.parse('$baseUrl/subjects/$subjectId/lectures')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        setState(() {
          lectureNotes = jsonDecode(utf8.decode(res.bodyBytes));
        });
      } else {
        setState(() {
          lectureNotes = [];
        });
      }
    } catch (e) {
      setState(() {
        lectureNotes = [];
      });
      _showFeedbackSnackBar('요약 노트를 불러오는 중 오류가 발생했습니다.', isError: true);
    } finally {
      setState(() {
        isLoadingNotes = false;
      });
    }
  }

  Future<void> uploadAudioFile() async {
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

  Future<void> toggleRecording() async {
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
          processStatus = '녹음 완료 (${_formatDuration(_recordSeconds)})! AI 분석 요청 중...';
        });

        if (path != null) {
          final response = await http.get(Uri.parse(path));
          await _processAudioPipeline(response.bodyBytes, 'lecture_recorded.m4a');
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
            processStatus = '🎙️ 강의 녹음 진행 중...';
          });
        } else {
          _showFeedbackSnackBar('마이크 접근 권한이 필요합니다.', isError: true);
          setState(() {
            processStatus = '마이크 사용 권한이 거부되었습니다.';
          });
        }
      }
    } catch (e) {
      _stopTimer();
      _showFeedbackSnackBar('녹음 제어 중 에러가 발생했습니다: $e', isError: true);
      setState(() {
        isRecording = false;
      });
    }
  }

  Future<void> _processAudioPipeline(List<int> bytes, String fileName) async {
    setState(() {
      isProcessing = true;
      latestNoteData = null;
      processStatus = '서버 전송 및 STT / 요약 / 퀴즈 생성 중... ($fileName)';
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/lectures/upload'));
      request.fields['subject_id'] = selectedSubjectId.toString();
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

      var streamedResponse = await request.send().timeout(const Duration(minutes: 3));
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var resData = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          processStatus = '✨ AI 요약 노트 생성 성공!';
          latestNoteData = {
            'title': fileName,
            'summary': resData['summary'] ?? resData['message'] ?? '요약 결과가 없습니다.',
            'transcript': resData['transcript'] ?? 'STT 변환 텍스트가 없습니다.',
            'keywords': resData['keywords'] ?? ['강의 핵심', 'AI 분석'],
            'quizzes': resData['quizzes'] ?? [],
          };
        });

        _showFeedbackSnackBar('✨ AI 요약 및 복습 퀴즈 작성이 완료되었습니다!');

        if (selectedSubjectId != null) {
          fetchLectures(selectedSubjectId!);
        }
      } else {
        _showFeedbackSnackBar('분석 실패 (서버 오류 코드: ${response.statusCode})', isError: true);
        setState(() {
          processStatus = '업로드 실패 (응답 코드: ${response.statusCode})';
        });
      }
    } catch (e) {
      _showFeedbackSnackBar('AI 분석 중 통신 오류가 발생했습니다.', isError: true);
      setState(() {
        processStatus = '분석 오류 발생: $e';
      });
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  void showNoteDetailModal(Map<String, dynamic> note) {
    final String title = note['title'] ?? note['filename'] ?? '강의 요약 노트';
    final String summary = note['summary'] ?? '요약 내용이 없습니다.';
    final String transcript = note['transcript'] ?? 'STT 음성 변환 기록이 없습니다.';
    final List<dynamic> keywords = note['keywords'] ?? ['AI 요약', '복습'];
    final List<dynamic> quizzes = note['quizzes'] ?? [];

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
                              const Text('🔑 핵심 키워드',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.indigo)),
                              const SizedBox(height: 8),
                              Wrap(
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
                              const Text('📝 3줄 핵심 요약',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.indigo)),
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
                              ? const Center(child: Text('생성된 AI 퀴즈가 없습니다.'))
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
                              const Text('🎙️ 음성 변환(STT) 전체 텍스트',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.indigo)),
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
            tooltip: '서버 연결 상태 다시 확인',
            onPressed: fetchData,
          )
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
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDuration(_recordSeconds),
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
                        return DropdownMenuItem<int>(
                          value: subject['id'] as int,
                          child: Text('${subject['title']} (${subject['instructor']})'),
                        );
                      }).toList(),
                      onChanged: (isProcessing || isRecording)
                          ? null
                          : (int? newValue) {
                              setState(() {
                                selectedSubjectId = newValue;
                                processStatus = '선택 과목 ID: $selectedSubjectId';
                              });
                              if (newValue != null) {
                                fetchLectures(newValue);
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      processStatus,
                      style: TextStyle(color: isRecording ? Colors.red : Colors.black87),
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
                            onPressed: (isRecording || selectedSubjectId == null) ? null : uploadAudioFile,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('파일 업로드'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: selectedSubjectId == null ? null : toggleRecording,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isRecording ? Colors.red : Colors.indigo,
                              foregroundColor: Colors.white,
                            ),
                            icon: Icon(isRecording ? Icons.stop : Icons.mic),
                            label: Text(isRecording ? '녹음 중지 및 분석' : '실시간 음성 녹음'),
                          ),
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
                  title: const Text('✨ 생성된 AI 노트 바로보기',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text('클릭하여 핵심 요약, 퀴즈, STT 원문 확인',
                      style: TextStyle(color: Colors.white70)),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                  onTap: () => showNoteDetailModal(latestNoteData!),
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
                    onPressed: () => fetchLectures(selectedSubjectId!),
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
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.article, color: Colors.indigo),
                        title: Text(note['title'] ?? note['filename'] ?? '강의 노트 ${index + 1}'),
                        subtitle: Text(note['created_at'] ?? '저장됨'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => showNoteDetailModal(note),
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
                  onPressed: showAddSubjectDialog,
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
                      bool isSelected = selectedSubjectId == subject['id'];

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
                            subject['title'],
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text('${subject['instructor']} | ⏰ ${subject['time_slot']}'),
                          trailing: isSelected
                              ? const Chip(
                                  label: Text('선택됨', style: TextStyle(fontSize: 11, color: Colors.indigo)),
                                  backgroundColor: Colors.white,
                                  side: BorderSide(color: Colors.indigo),
                                )
                              : null,
                          onTap: () {
                            setState(() {
                              selectedSubjectId = subject['id'] as int;
                              processStatus = '선택 과목: ${subject['title']}';
                            });
                            fetchLectures(subject['id'] as int);
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

// 📌 퀴즈 위젯
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
    final options = widget.quiz['options'] as List<dynamic>;
    final int correctAnswer = widget.quiz['answer'] ?? 0;
    final String explanation = widget.quiz['explanation'] ?? '핵심 요약 내용을 참고하세요.';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Q${widget.index + 1}. ${widget.quiz['question']}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 10),
            ...options.asMap().entries.map((entry) {
              int optIdx = entry.key;
              String optText = entry.value;

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