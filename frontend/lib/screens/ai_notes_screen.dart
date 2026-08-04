import 'package:flutter/material.dart';

class AiNotesScreen extends StatelessWidget {
  const AiNotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 노트')),
      body: const Center(child: Text('19일차: AI 노트 및 퀴즈 모아보기 화면')),
    );
  }
}