import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';
import '../main.dart'; // ApiConfig 참조
import 'package:provider/provider.dart';
import 'package:frontend/subject_provider.dart';

class AiNotesScreen extends StatefulWidget {
  const AiNotesScreen({super.key});

  @override
  State<AiNotesScreen> createState() => _AiNotesScreenState();
}

class _AiNotesScreenState extends State<AiNotesScreen> {
  final ApiService _apiService = ApiService();

  int? _selectedSubjectId;

  List<dynamic> _notes = [];
  bool _isLoadingNotes = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // 화면이 처음 활성화될 때 Provider 데이터 기반으로 노트 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncAndFetchNotes();
    });
  }

  // Provider 목록을 참조하여 첫 번 과목 노트 불러오기
  void _syncAndFetchNotes() {
    final subjects = context.read<SubjectProvider>().subjects;
    if (subjects.isNotEmpty) {
      if (_selectedSubjectId == null ||
          !subjects.any((s) => int.tryParse(s['id'].toString()) == _selectedSubjectId)) {
        _selectedSubjectId = int.tryParse(subjects.first['id'].toString());
      }
      if (_selectedSubjectId != null) {
        _fetchNotesForSubject(_selectedSubjectId!);
      }
    } else {
      setState(() {
        _selectedSubjectId = null;
        _notes = [];
      });
    }
  }

  // 선택된 과목의 강의 요약 노트 목록 불러오기
  Future<void> _fetchNotesForSubject(int subjectId) async {
    setState(() {
      _isLoadingNotes = true;
      _errorMessage = null;
    });

    try {
      final notesData = await _apiService.getLecturesBySubject(subjectId);
      setState(() {
        _notes = notesData;
      });
    } catch (e) {
      setState(() {
        _notes = [];
        _errorMessage = '노트를 불러오는 중 오류가 발생했습니다: $e';
      });
    } finally {
      setState(() {
        _isLoadingNotes = false;
      });
    }
  }

  // 강의 노트 제목 수정 API 호출
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

  // ✨ 강의 노트 삭제 API 호출
  Future<void> _deleteLectureNote(int lectureId) async {
    try {
      final baseUrl = ApiConfig.baseUrl;
      final response = await http.delete(
        Uri.parse('$baseUrl/lectures/$lectureId'),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('노트가 삭제되었습니다.')),
          );
        }
        if (_selectedSubjectId != null) {
          await _fetchNotesForSubject(_selectedSubjectId!);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('노트 삭제 실패 (${response.statusCode})')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('네트워크 오류로 노트를 삭제하지 못했습니다: $e')),
        );
      }
    }
  }

  // ✨ 삭제 확인 다이얼로그
  void _showDeleteConfirmDialog(int lectureId, String noteTitle) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
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
                await _deleteLectureNote(lectureId);
              },
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
  }

  // 제목 수정 다이얼로그
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

  // AI 퀴즈 풀어보기 모달 다이얼로그
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
    // Provider로부터 실시간 최신 과목 목록을 관찰(watch)합니다.
    final subjects = context.watch<SubjectProvider>().subjects;

    // 현재 선택된 ID가 실제 subjects 리스트 안에 존재하는지 안전 검사 (에러 방지 핵심)
    final bool isSelectedValid = subjects.any(
      (s) => int.tryParse(s['id'].toString()) == _selectedSubjectId,
    );

    // 만약 선택된 과목이 목록에 없으면 첫 번째 과목으로 자동 보정
    final int? currentSelectedValue = isSelectedValid
        ? _selectedSubjectId
        : (subjects.isNotEmpty ? int.tryParse(subjects.first['id'].toString()) : null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 강의 요약 노트', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: () {
              context.read<SubjectProvider>().fetchSubjects();
              if (currentSelectedValue != null) {
                _fetchNotesForSubject(currentSelectedValue);
              }
            },
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
                  child: subjects.isEmpty
                      ? const Text('등록된 과목이 없습니다.')
                      : DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: currentSelectedValue,
                            isExpanded: true,
                            items: subjects.map<DropdownMenuItem<int>>((sub) {
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
                                          // ✨ 노트 삭제 버튼 추가
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline,
                                                color: Colors.redAccent, size: 20),
                                            tooltip: '노트 삭제',
                                            onPressed: () =>
                                                _showDeleteConfirmDialog(noteId, titleText),
                                          ),
                                          const SizedBox(width: 4),
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