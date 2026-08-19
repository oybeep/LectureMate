import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:frontend/subject_provider.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../main.dart';
import '../services/api_service.dart';

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
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncAndFetchNotes();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _syncAndFetchNotes() {
    if (!mounted) return;
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

  Future<void> _fetchNotesForSubject(int subjectId, {bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoadingNotes = true;
        _errorMessage = null;
      });
    }

    try {
      final notesData = await _apiService.getLecturesBySubject(subjectId);
      if (!mounted) return;

      setState(() {
        _notes = notesData;
      });

      // 요약 진행 중인 노특가 있을 때만 4초 마다 폴링
      bool hasProcessingNote = _notes.any((note) {
        final summary = note['summary']?.toString().trim() ?? '';
        return summary.isEmpty;
      });

      if (hasProcessingNote) {
        _checkAndStartPolling(subjectId);
      } else {
        _pollingTimer?.cancel();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _notes = [];
        _errorMessage = '노트를 불러오는 중 오류가 발생했습니다: $e';
      });
    } finally {
      if (mounted && showLoading) {
        setState(() {
          _isLoadingNotes = false;
        });
      }
    }
  }

  void _checkAndStartPolling(int subjectId) {
    if (_pollingTimer?.isActive ?? false) return;

    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (mounted && _selectedSubjectId == subjectId) {
        await _fetchNotesForSubject(subjectId, showLoading: false);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _deleteLectureNote(int lectureId) async {
    try {
      await _apiService.deleteLecture(lectureId);
      if (_selectedSubjectId != null) {
        _fetchNotesForSubject(_selectedSubjectId!, showLoading: false);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('노트가 삭제되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Future<void> _renameLectureNote(int lectureId, String newTitle) async {
    try {
      await _apiService.updateLectureTitle(lectureId, newTitle);
      if (_selectedSubjectId != null) {
        _fetchNotesForSubject(_selectedSubjectId!, showLoading: false);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('제목이 수정되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('수정 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  void _showDeleteConfirmDialog(int lectureId, String noteTitle) {
    showDialog(
      context: context,
      builder: (dialogContext) {
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
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _deleteLectureNote(lectureId);
              },
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
  }

  void _showEditTitleDialog(int lectureId, String currentTitle) {
    final titleController = TextEditingController(text: currentTitle);

    showDialog(
      context: context,
      builder: (dialogContext) {
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
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                final updatedTitle = titleController.text.trim();
                if (updatedTitle.isNotEmpty) {
                  Navigator.pop(dialogContext);
                  await _renameLectureNote(lectureId, updatedTitle);
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
      builder: (dialogContext) {
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
                    onPressed: () => Navigator.pop(dialogContext),
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
    final subjects = context.watch<SubjectProvider>().subjects;

    final bool isSelectedValid = subjects.any(
      (s) => int.tryParse(s['id'].toString()) == _selectedSubjectId,
    );

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
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: _isLoadingNotes
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () async {
                      if (currentSelectedValue != null) {
                        await _fetchNotesForSubject(currentSelectedValue);
                      }
                    },
                    child: _notes.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(), // 💡 빈 화면에서도 새로고침 스크롤 가능하도록 추가
                            children: const [
                              SizedBox(height: 150),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.note_alt_outlined, size: 64, color: Colors.grey),
                                    SizedBox(height: 12),
                                    Text(
                                      '해당 과목에 저장된 AI 요약 노트가 없습니다.',
                                      style: TextStyle(color: Colors.grey, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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

                              final rawKeywords = note['keywords'] ?? note['key_concepts'];
                              final List<dynamic> keywords = (rawKeywords is List && rawKeywords.isNotEmpty)
                                  ? rawKeywords
                                  : ['분석 중...'];

                              final List<dynamic> quizzes = (note['quizzes'] is List)
                                  ? note['quizzes']
                                  : ((note['quiz'] is List) ? note['quiz'] : []);

                              final String createdAtText =
                                  note['created_at']?.toString() ?? note['date']?.toString() ?? '';
                              final String displayDate =
                                  createdAtText.length >= 10 ? createdAtText.substring(0, 10) : '저장됨';

                              final String rawSummary = note['summary']?.toString().trim() ?? '';
                              final bool isProcessing = rawSummary.isEmpty;
                              final String summaryText = isProcessing
                                  ? '⏳ 백엔드에서 AI 요약을 작성 중입니다. 잠시만 기다려주세요...'
                                  : rawSummary;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  // 💡 카드 전체 클릭 시 상세 페이지 연결 (필요한 DetailScreen 클래스명 지정)
                                  onTap: () {
        
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => LectureNoteDetailScreen(noteData: note),
                                      ),
                                    );
                                  },
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
                                        Row(
                                          children: [
                                            const Text(
                                              '📝 핵심 요약',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold, color: Colors.indigo),
                                            ),
                                            if (isProcessing) ...[
                                              const SizedBox(width: 8),
                                              const SizedBox(
                                                width: 12,
                                                height: 12,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              ),
                                            ]
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          summaryText,
                                          style: TextStyle(
                                              fontSize: 14,
                                              height: 1.4,
                                              color: isProcessing ? Colors.orange.shade800 : Colors.black87),
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
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// 📖 전체화면 AI 노트 상세 (STT 정제 스크립트 / 세부 강의노트 / 5대 맞춤 AI 정리노트)
// ===========================================================================

class LectureNoteDetailScreen extends StatefulWidget {
  final Map<String, dynamic> noteData;

  const LectureNoteDetailScreen({super.key, required this.noteData});

  @override
  State<LectureNoteDetailScreen> createState() => _LectureNoteDetailScreenState();
}

class _LectureNoteDetailScreenState extends State<LectureNoteDetailScreen> {
  int _currentTabIndex = 1; // 기본값: 1번 탭 (세부 강의노트)

  // STT 정제 상태 관리
  int _sttViewMode = 0; // 0: 가독성 정제본, 1: 원문 그대로
  String? _cleanedTranscript;
  bool _isLoadingCleanSTT = false;

  // 맞춤 AI 노트 상태 관리
  String _selectedFormat = 'cornell';
  String? _generatedCustomContent;
  bool _isLoadingFormat = false;

  final Map<String, Map<String, dynamic>> _formatOptions = {
    'cornell': {
      'title': '코넬 노트',
      'desc': '핵심 키워드, 질문, 체계적 필기 및 최종 요약',
      'icon': Icons.view_sidebar_outlined,
    },
    'exam': {
      'title': '시험 대비 노트',
      'desc': '교수님 강조 내용, 중요도, 암기 포인트, 실전 예상 시험 문제',
      'icon': Icons.assignment_turned_in_outlined,
    },
    'outline': {
      'title': '아웃라인 노트',
      'desc': '주제와 하위 주제를 계층화하여 전체 개념 구조를 개조식 정리',
      'icon': Icons.format_list_bulleted,
    },
    'flashcard': {
      'title': '플래시카드',
      'desc': '앞면 질문과 뒷면 정답/설명으로 구성된 반복 암기 카드',
      'icon': Icons.style_outlined,
    },
    'feynman': {
      'title': 'Feynman 노트',
      'desc': '전문 용어를 배제하고 쉬운 말과 비유로 직관적 해설',
      'icon': Icons.psychology_outlined,
    },
  };

  @override
  void initState() {
    super.initState();
    // 💡 1. 로딩 상태 및 데이터 복원
    _isLoadingCleanSTT = widget.noteData['is_loading_stt'] ?? false;
    _isLoadingFormat = widget.noteData['is_loading_format'] ?? false;

    _cleanedTranscript = widget.noteData['cleaned_transcript'] ?? widget.noteData['cleaned_stt'];
    _generatedCustomContent = widget.noteData['custom_note'] ?? widget.noteData['custom_content'];

    // 💡 2. 화면 진입 시 최신 DB 조회
    _fetchLatestLectureData();
  }

  // 최신 데이터 조회 및 동기화
  Future<void> _fetchLatestLectureData() async {
    final noteId = widget.noteData['id'] ?? widget.noteData['lecture_id'];
    if (noteId == null) return;

    try {
      final baseUrl = ApiConfig.baseUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/lectures/$noteId'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final lecture = data['data'] ?? data;

        if (mounted) {
          setState(() {
            if (!_isLoadingCleanSTT) {
              _cleanedTranscript =
                  lecture['cleaned_transcript'] ?? lecture['cleaned_stt'] ?? _cleanedTranscript;
            }
            if (!_isLoadingFormat) {
              _generatedCustomContent =
                  lecture['custom_note'] ?? lecture['custom_content'] ?? _generatedCustomContent;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('최신 강의 데이터 조회 실패: $e');
    }
  }

  // DB 영구 저장 헬퍼
  Future<void> _updateLectureInDb(Map<String, dynamic> updateFields) async {
    final noteId = int.tryParse((widget.noteData['id'] ?? widget.noteData['lecture_id']).toString()) ?? 0;
    if (noteId == 0) return;

    try {
      final baseUrl = ApiConfig.baseUrl;
      await http.patch(
        Uri.parse('$baseUrl/lectures/$noteId'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(updateFields),
      );
    } catch (e) {
      debugPrint('DB 자동 저장 실패: $e');
    }
  }

  // 1. STT 가독성 정제본 요청
  Future<void> _fetchCleanedSTT() async {
    final rawStt = widget.noteData['stt_text'] ??
        widget.noteData['transcript'] ??
        widget.noteData['stt_transcript'] ??
        '';

    if (rawStt.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('정제할 STT 원문 텍스트가 없습니다.')),
        );
      }
      return;
    }

    final currentLectureId = widget.noteData['id'] ?? widget.noteData['lecture_id'];

    if (mounted) {
      setState(() {
        _isLoadingCleanSTT = true;
      });
    }

    try {
      final baseUrl = ApiConfig.baseUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/notes/clean-stt'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'stt_text': rawStt,
          'lecture_id': currentLectureId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final cleaned = (data['cleaned_transcript'] ?? data['content']) as String?;

        if (cleaned != null && cleaned.isNotEmpty) {
          if (mounted) {
            setState(() {
              _cleanedTranscript = cleaned;
            });
          }
          await _updateLectureInDb({'cleaned_transcript': cleaned});
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('정제본 생성 실패 (${response.statusCode})')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('네트워크 오류: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCleanSTT = false;
        });
      }
    }
  }

  // 2. 5대 맞춤 노트 생성 요청
  Future<void> _fetchCustomFormat(String formatType) async {
    final stt = widget.noteData['stt_text'] ??
        widget.noteData['transcript'] ??
        widget.noteData['summary'] ??
        '';

    if (stt.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('노트를 생성할 원문 내용이 없습니다.')),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _selectedFormat = formatType;
        _isLoadingFormat = true;
      });
    }

    try {
      final baseUrl = ApiConfig.baseUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/notes/generate-custom'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'stt_text': stt,
          'format_type': formatType,
          'lecture_id': widget.noteData['id'] ?? widget.noteData['lecture_id'],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = (data['custom_note'] ?? data['content']) as String?;

        if (content != null && content.isNotEmpty) {
          if (mounted) {
            setState(() {
              _generatedCustomContent = content;
            });
          }
          await _updateLectureInDb({'custom_note': content});
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('생성 실패 (${response.statusCode})')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('네트워크 오류: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFormat = false;
        });
      }
    }
  }

  void _showFormatSelectSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '✨ AI 정리노트 형식 선택',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ..._formatOptions.entries.map((entry) {
                final key = entry.key;
                final info = entry.value;
                return ListTile(
                  leading: Icon(info['icon'] as IconData, color: Colors.indigo),
                  title: Text(
                    info['title'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    info['desc'] as String,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _fetchCustomFormat(key);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  String _formatDetailedSummary(dynamic detailedData) {
    if (detailedData == null) return '세부 강의 노트 내용이 없습니다.';

    // 1. 단순 String 처리
    if (detailedData is String) {
      final trimmed = detailedData.trim();
      if (trimmed.isEmpty) return '세부 강의 노트 내용이 없습니다.';

      return trimmed
          .replaceAll('• ', '\n- ')
          .replaceAll('복소 평면', '\n복소 평면')
          .trim();
    }

    // 2. List 형태 처리
    if (detailedData is List) {
      if (detailedData.isEmpty) return '세부 강의 노트 내용이 없습니다.';

      final buffer = StringBuffer();

      for (var item in detailedData) {
        if (item is Map) {
          final title = item['title'] ?? item['topic'] ?? item['header'] ?? '주요 소주제';
          buffer.writeln('### 📌 $title\n');

          if (item['points'] != null && item['points'] is List) {
            final List points = item['points'];
            for (var pt in points) {
              buffer.writeln('- ${pt.toString()}\n');
            }
            buffer.writeln('');
          } else if (item['content'] != null || item['description'] != null) {
            final content = item['content'] ?? item['description'] ?? '';
            buffer.writeln('$content\n\n');
          } else {
            buffer.writeln('*상세 설명이 제공되지 않았습니다.*\n\n');
          }

          buffer.writeln('---\n');
        } else if (item != null) {
          final cleanedItem = item.toString().replaceAll('• ', '').trim();
          buffer.writeln('- $cleanedItem\n');
        }
      }

      return buffer.toString().trim();
    }

    return detailedData.toString();
  }

  Widget _buildSttView(String sttRawText) {
    if (_sttViewMode == 1) {
      return SingleChildScrollView(
        child: SelectableText(
          sttRawText,
          style: const TextStyle(fontSize: 15, height: 1.7, color: Colors.black87),
        ),
      );
    }

    if (_isLoadingCleanSTT) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('STT 스크립트를 읽기 쉽게 정제하는 중입니다...'),
          ],
        ),
      );
    }

    if (_cleanedTranscript == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('아직 생성된 가독성 정제본이 없습니다.'),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _fetchCleanedSTT,
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('지금 정제본 생성하기'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: MarkdownBody(
        data: _cleanedTranscript!,
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          p: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
          h2: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo),
        ),
      ),
    );
  }

  Widget _buildCustomNoteView() {
    if (_isLoadingFormat) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'AI가 맞춤 노트를 생성하고 있습니다...',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    if (_generatedCustomContent == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome, size: 56, color: Colors.indigo),
            const SizedBox(height: 12),
            const Text(
              '원하는 학습 노트 형식을 선택하세요.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              '코넬, 시험 대비, 아웃라인, 플래시카드, Feynman 테크닉을 지원합니다.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showFormatSelectSheet,
              icon: const Icon(Icons.format_shapes),
              label: const Text('양식 선택 및 생성하기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.indigo.shade100),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: MarkdownBody(
            data: _generatedCustomContent!,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: const TextStyle(fontSize: 15, height: 1.6),
              h1: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo),
              h2: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.indigoAccent),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.noteData['title'] ??
        widget.noteData['lecture_title'] ??
        widget.noteData['filename'] ??
        '강의 상세 노트';

    final sttRawText = widget.noteData['stt_text'] ??
        widget.noteData['transcript'] ??
        widget.noteData['stt_transcript'] ??
        '추출된 STT 원문 텍스트가 없습니다.';

    final detailedSummaryRaw = widget.noteData['detailed_summary'] ??
        widget.noteData['detail_summary'] ??
        widget.noteData['details'] ??
        widget.noteData['summary'];

    final formattedDetailedSummary = _formatDetailedSummary(detailedSummaryRaw);

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_currentTabIndex == 2)
            IconButton(
              icon: const Icon(Icons.style_outlined),
              tooltip: '양식 변경',
              onPressed: _showFormatSelectSheet,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: IndexedStack(
          index: _currentTabIndex,
          children: [
            // 0️⃣ STT 스크립트
            Column(
              children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: Text('✨ AI 가독성 정제본'),
                      icon: Icon(Icons.auto_fix_high),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('📝 원문 그대로'),
                      icon: Icon(Icons.raw_on_outlined),
                    ),
                  ],
                  selected: {_sttViewMode},
                  onSelectionChanged: (Set<int> newSelection) {
                    setState(() {
                      _sttViewMode = newSelection.first;
                    });
                    if (_sttViewMode == 0 && _cleanedTranscript == null && !_isLoadingCleanSTT) {
                      _fetchCleanedSTT();
                    }
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Card(
                    elevation: 0,
                    color: Colors.grey.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildSttView(sttRawText),
                    ),
                  ),
                ),
              ],
            ),

            // 1️⃣ 세부 강의노트 (💡 SizedBox.expand 제거 및 스크롤 최적화)
            SingleChildScrollView(
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: MarkdownBody(
                    data: formattedDetailedSummary,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                      p: const TextStyle(fontSize: 15, height: 1.6),
                      h3: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold, color: Colors.indigo),
                    ),
                  ),
                ),
              ),
            ),

            // 2️⃣ ✨ 5대 AI 맞춤 정리노트 (💡 SizedBox.expand 제거)
            _buildCustomNoteView(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: 'STT 스크립트',
          ),
          NavigationDestination(
            icon: Icon(Icons.notes_outlined),
            selectedIcon: Icon(Icons.notes),
            label: '세부 강의노트',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'AI 맞춤노트',
          ),
        ],
      ),
    );
  }
}