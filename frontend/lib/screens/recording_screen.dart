import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:frontend/subject_provider.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final String? timestamp;
  final String? displayText;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.timestamp,
    this.displayText,
  });
}

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  final List<ChatMessage> _messages = [
    ChatMessage(
      text: "안녕하세요! 질문하실 내용을 입력하시면 저장된 강의 노트 및 STT 기록을 통해 답변해 드립니다.",
      isUser: false,
    )
  ];

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  String _selectedSubject = "전체 과목"; // 과목 필터용

  @override
  void initState() {
    super.initState();
    // 화면이 진입할 때 과목 데이터 최신화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubjectProvider>().fetchSubjects();
    });
  }

  // AI 검색 API (/api/lectures/search) 호출
  Future<void> _sendMessage() async {
    final query = _textController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: query, isUser: true));
      _isLoading = true;
    });
    _textController.clear();
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/api/lectures/search'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'subject': _selectedSubject,
          'query': query,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _messages.add(ChatMessage(
            text: data['answer'] ?? "관련된 강의 내용을 찾을 수 없습니다.",
            isUser: false,
            timestamp: data['timestamp'],
            displayText: data['display_text'],
          ));
        });
      } else {
        _showErrorMessage("서버 응답 에러 (${response.statusCode})");
      }
    } catch (e) {
      _showErrorMessage("통신 에러가 발생했습니다.");
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _showErrorMessage(String msg) {
    setState(() {
      _messages.add(ChatMessage(
        text: msg,
        isUser: false,
      ));
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 💡 SubjectProvider에서 최신 과목 데이터 구독
    final provider = context.watch<SubjectProvider>();
    final List<String> subjects = [
      "전체 과목",
      ...provider.subjects
          .map((e) => (e["title"] ?? e["name"] ?? "").toString())
          .where((title) => title.isNotEmpty)
          .toList()
    ];

    // 현재 선택된 과목이 목록에 없으면 '전체 과목'으로 안전하게 복구
    final currentSelected =
        subjects.contains(_selectedSubject) ? _selectedSubject : "전체 과목";

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 강의 질의응답',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.inversePrimary,
        actions: [
          // 과목 선택 드롭다운 버튼
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currentSelected,
                icon: Icon(Icons.filter_list, color: colorScheme.onSurface),
                dropdownColor: colorScheme.surface,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedSubject = newValue;
                    });
                  }
                },
                items: subjects.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          // 현재 선택된 검색 대상 과목 태그 (테마 자동 대응)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: colorScheme.surfaceContainer,
            child: Row(
              children: [
                Icon(Icons.psychology, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '검색 대상: ',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  currentSelected,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // 대화 메시지 목록
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment: msg.isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: msg.isUser
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(msg.isUser ? 16 : 2),
                        bottomRight: Radius.circular(msg.isUser ? 2 : 16),
                      ),
                      border: msg.isUser
                          ? null
                          : Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          msg.text,
                          style: TextStyle(
                            fontSize: 15,
                            color: msg.isUser
                                ? colorScheme.onPrimary
                                : colorScheme.onSurface,
                            height: 1.4,
                          ),
                        ),

                        // 백엔드에서 타임스탬프를 반환해준 경우 표시
                        if (msg.timestamp != null &&
                            msg.timestamp != "00:00") ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.access_time,
                                    size: 14,
                                    color: colorScheme.onPrimaryContainer),
                                const SizedBox(width: 4),
                                Text(
                                  '강의 구간: ${msg.timestamp}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: colorScheme.primary,
                ),
              ),
            ),

          // 질문 입력 바 (다크모드 고정 하얀색 문제 해결)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: '강의 내용에 대해 질문해보세요...',
                        hintStyle: TextStyle(
                          color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainer,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}