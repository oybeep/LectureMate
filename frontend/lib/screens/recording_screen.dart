import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
      text: "안녕하세요! 질문하실 내용을 입력하시면 저장된 강의 노트 및 STT 기록에서 타임스탬프와 함께 답변해 드립니다.",
      isUser: false,
    )
  ];

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool _isLoading = false;
  String _selectedSubject = "전체 과목"; // 과목 필터용
  List<String> _subjects = ["전체 과목"];

  @override
  void initState() {
    super.initState();
    _fetchSubjects();
  }

  // 서버에서 과목 목록 불러오기
  Future<void> _fetchSubjects() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:8000/subjects'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _subjects = ["전체 과목"] + data.map((e) => e["title"].toString()).toList();
        });
      }
    } catch (_) {
      // 과목 불러오기 실패 시 기본값 유지
    }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 강의 질의응답', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // 과목 선택 드롭다운 버튼
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _subjects.contains(_selectedSubject) ? _selectedSubject : _subjects.first,
                icon: const Icon(Icons.filter_list),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedSubject = newValue;
                    });
                  }
                },
                items: _subjects.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
          // 현재 선택된 검색 대상 과목 태그
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.indigo.shade50,
            child: Row(
              children: [
                const Icon(Icons.psychology, size: 20, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(
                  '검색 대상: ',
                  style: TextStyle(fontSize: 13, color: Colors.indigo.shade900, fontWeight: FontWeight.bold),
                ),
                Text(
                  _selectedSubject,
                  style: const TextStyle(fontSize: 13, color: Colors.indigo, fontWeight: FontWeight.w600),
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
                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: msg.isUser ? Colors.indigo : Colors.grey.shade100,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(msg.isUser ? 16 : 2),
                        bottomRight: Radius.circular(msg.isUser ? 2 : 16),
                      ),
                      border: msg.isUser ? null : Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          msg.text,
                          style: TextStyle(
                            fontSize: 15,
                            color: msg.isUser ? Colors.white : Colors.black87,
                            height: 1.4,
                          ),
                        ),
                        
                        // 백엔드에서 타임스탬프를 반환해준 경우 표시
                        if (msg.timestamp != null && msg.timestamp != "00:00") ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.access_time, size: 14, color: Colors.indigo),
                                const SizedBox(width: 4),
                                Text(
                                  '강의 구간: ${msg.timestamp}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo,
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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),

          // 질문 입력 바
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
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
                      decoration: InputDecoration(
                        hintText: '강의 내용에 대해 질문해보세요...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
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