import 'package:flutter/material.dart';

class TimetableScreen extends StatelessWidget {
  const TimetableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('시간표')),
      body: const Center(child: Text('16일차: 시간표 및 과목 관리 화면')),
    );
  }
}