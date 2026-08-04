import 'package:flutter/material.dart';

class RecordingScreen extends StatelessWidget {
  const RecordingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('강의 녹음')),
      body: const Center(child: Text('17일차: 음성 녹음 전용 화면')),
    );
  }
}