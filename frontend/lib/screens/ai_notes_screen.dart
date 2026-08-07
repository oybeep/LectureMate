import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';
import '../main.dart'; // ApiConfig 참조

class AiNotesScreen extends StatefulWidget {
  const AiNotesScreen({super.key});

  @override
  State<AiNotesScreen> createState() => _AiNotesScreenState();
}

class _AiNotesScreenState extends State<AiNotesScreen> {
  final ApiService _apiService = ApiService();

  List<dynamic> _subjects = [];
  int? _selectedSubjectId;

  List<dynamic> _notes = [];
  bool _isLoadingSubjects = false;
  bool _isLoadingNotes = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchSubjects();
    });
  }

  // 1. 과목 목록 불러오기
  Future<void> _fetchSubjects() async {
    setState(() {
      _isLoadingSubjects = true;
      _errorMessage = null;
    });

    try {
      final subjectsData = await _apiService.getSubjects();
      setState(() {
        _subjects = subjectsData;
        if (_subjects.isNotEmpty) {
          // 기존 선택값이 목록에 없는 경우 첫 번째 과목 선택
          if (_selectedSubjectId == null ||
              !_subjects.any((s) => int.tryParse(s['id'].toString()) == _selectedSubjectId)) {
            _selectedSubjectId = int.tryParse(_subjects.first['id'].toString());
          }
          if (_selectedSubjectId != null) {
            _fetchNotesForSubject(_selectedSubjectId!);
          }
        } else {
          _selectedSubjectId = null;
          _notes = [];
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = '과목 목록을 불러오는 중 오류가 발생했습니다: $e';
      });
    } finally {
      setState(() {
        _isLoadingSubjects = false;
      });
    }
  }

  // 2. 선택된 과목의 강의 요약 노트 목록 불러오기
  Future<void> _fetchNotesForSubject(int subjectId) async {
    setState(() {
      _isLoadingNotes = true;
    });

    try {
      final notesData = await _apiService.getLecturesBySubject(subjectId);
      setState(() {
        _notes = notesData;
      });
    } catch (e) {
      setState(() {
        _notes = [];
      });
    } finally {
      setState(() {
        _isLoadingNotes = false;
      });
    }
  }

  // 3. 강의 노트 제목 수정 API 호출
  Future<void> _renameLectureNote(int lectureId, String newTitle) async {
    try {
      final baseUrl = ApiConfig.baseUrl;
      final response = await http.patch(
        Uri.parse('$baseUrl/lectures/$lectureId'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'title': newTitle}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('노트 제목이 변경되었습니다.')),
          );
        }
        if (_selectedSubjectId != null) {
          await _fetchNotesForSubject(_selectedSubjectId!);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('제목 수정 실패 (${response.statusCode})')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('네트워크 오류로 제목을 수정하지 못했습니다: $e')),
        );
      }
    }
  }

  // 4. 제목 수정 다이얼로그
  void _showEditTitleDialog(int lectureId, String currentTitle) {
    final titleController = TextEditingController(text: currentTitle);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.edit_note, color: Colors.indigo),
              SizedBox(width: 8),
              Text('노트 제목 수정'),
            ],
          ),
          content: TextField(
            controller: titleController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '새 노트 제목',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                final updatedTitle = titleController.text.trim();
                if (updatedTitle.isNotEmpty) {
                  await _renameLectureNote(lectureId, updatedTitle);
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('제목을 입력해 주세요.')),
                  );
                }
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }

  // 5. AI 퀴즈 풀어보기 모달 다이얼로그
  void _showQuizDialog(List<dynamic> quizzes) {
    if (quizzes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('생성된 AI 퀴즈가 없습니다.')),
      );
      return;
    }

    int currentQuizIndex = 0;
    int? selectedOption;
    bool isAnswerChecked = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final quiz = quizzes[currentQuizIndex];
            final List<dynamic> options = quiz['options'] ?? quiz['choices'] ?? [];
            final int correctAnswer = int.tryParse(quiz['answer']?.toString() ?? '0') ?? 0;
            final String explanation = quiz['explanation'] ?? '해설이 제공되지 않았습니다.';

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.quiz, color: Colors.indigo),
                  const SizedBox(width: 8),
                  Text('AI 복습 퀴즈 (${currentQuizIndex + 1}/${quizzes.length})'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Q${currentQuizIndex + 1}. ${quiz['question'] ?? '문제 내용 없음'}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(options.length, (idx) {
                      Color? tileColor;
                      if (isAnswerChecked) {
                        if (idx == correctAnswer) {
                          tileColor = Colors.green.shade100;
                        } else if (selectedOption == idx) {
                          tileColor = Colors.red.shade100;
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: tileColor ?? Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: RadioListTile<int>(
                          value: idx,
                          groupValue: selectedOption,
                          title: Text('${idx + 1}) ${options[idx]}'),
                          onChanged: isAnswerChecked
                              ? null
                              : (val) {
                                  setDialogState(() {
                                    selectedOption = val;
                                  });
                                },
                        ),
                      );
                    }),
                    if (isAnswerChecked) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          selectedOption == correctAnswer
                              ? '🎉 정답입니다!\n💡 해설: $explanation'
                              : '❌ 오답입니다. (정답: ${correctAnswer + 1}번)\n💡 해설: $explanation',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: selectedOption == correctAnswer
                                ? Colors.green.shade900
                                : Colors.red.shade900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                if (!isAnswerChecked)
                  ElevatedButton(
                    onPressed: selectedOption == null
                        ? null
                        : () {
                            setDialogState(() {
                              isAnswerChecked = true;
                            });
                          },
                    child: const Text('정답 확인'),
                  )
                else if (currentQuizIndex < quizzes.length - 1)
                  ElevatedButton(
                    onPressed: () {
                      setDialogState(() {
                        currentQuizIndex++;
                        selectedOption = null;
                        isAnswerChecked = false;
                      });
                    },
                    child: const Text('다음 문제'),
                  )
                else
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('닫기'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 강의 요약 노트', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: _fetchSubjects,
          ),
        ],
      ),
      body: Column(
        children: [
          // 과목 선택 드롭다운 영역
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.indigo.shade50,
            child: Row(
              children: [
                const Icon(Icons.class_outlined, color: Colors.indigo),
                const SizedBox(width: 12),
                const Text('과목 선택: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Expanded(
                  child: _isLoadingSubjects
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _subjects.isEmpty
                          ? const Text('등록된 과목이 없습니다.')
                          : DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _selectedSubjectId,
                                isExpanded: true,
                                items: _subjects.map<DropdownMenuItem<int>>((sub) {
                                  final int subId = int.tryParse(sub['id'].toString()) ?? 0;
                                  final String profName = sub['instructor'] ??
                                      sub['professor'] ??
                                      sub['professor_name'] ??
                                      '교수 미지정';
                                  final String subTitle =
                                      sub['title'] ?? sub['name'] ?? sub['subject_name'] ?? '과목';
                                  return DropdownMenuItem<int>(
                                    value: subId,
                                    child: Text('$subTitle ($profName)'),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedSubjectId = val;
                                    });
                                    _fetchNotesForSubject(val);
                                  }
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),

          // 에러 메시지 출력 영역
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ),

          // 강의 노트 목록 출력 영역
          Expanded(
            child: _isLoadingNotes
                ? const Center(child: CircularProgressIndicator())
                : _notes.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.note_alt_outlined, size: 64, color: Colors.grey),
                            SizedBox(height: 12),
                            Text(
                              '해당 과목에 저장된 AI 요약 노트가 없습니다.',
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _notes.length,
                        itemBuilder: (context, index) {
                          final note = Map<String, dynamic>.from(_notes[index]);
                          final int noteId =
                              int.tryParse((note['id'] ?? note['lecture_id']).toString()) ?? 0;
                          final String titleText = note['title'] ??
                              note['lecture_title'] ??
                              note['filename'] ??
                              '강의 노트 ${index + 1}';

                          final List<dynamic> keywords =
                              note['keywords'] ?? note['key_concepts'] ?? ['AI 분석'];
                          final List<dynamic> quizzes = note['quizzes'] ?? note['quiz'] ?? [];

                          final String createdAtText =
                              note['created_at']?.toString() ?? note['date']?.toString() ?? '';
                          final String displayDate =
                              createdAtText.length >= 10 ? createdAtText.substring(0, 10) : '저장됨';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          titleText,
                                          style: const TextStyle(
                                              fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined,
                                                color: Colors.indigo, size: 20),
                                            tooltip: '노트 제목 수정',
                                            onPressed: () =>
                                                _showEditTitleDialog(noteId, titleText),
                                          ),
                                          Text(
                                            displayDate,
                                            style: const TextStyle(
                                                color: Colors.grey, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  const Text(
                                    '📝 핵심 요약',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold, color: Colors.indigo),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    note['summary'] ?? '요약 내용이 없습니다.',
                                    style: const TextStyle(
                                        fontSize: 14, height: 1.4, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    '🏷️ 주요 키워드',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold, color: Colors.indigo),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: keywords.map((kw) {
                                      return Chip(
                                        label: Text(
                                          kw.toString(),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        backgroundColor: Colors.indigo.shade50,
                                        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                                        visualDensity: VisualDensity.compact,
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _showQuizDialog(quizzes),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.indigo,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      icon: const Icon(Icons.quiz_outlined),
                                      label: Text('AI 복습 퀴즈 풀어보기 (${quizzes.length}문항)'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}