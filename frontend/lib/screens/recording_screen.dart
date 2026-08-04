import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io';
import '../services/api_service.dart';
import 'package:flutter/foundation.dart'; // kIsWeb 사용을 위해 추가

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {

  final ApiService _apiService = ApiService();
  bool _isUploading = false;

  late final AudioRecorder _audioRecorder;
  bool _isRecording = false;
  bool _isPaused = false;
  
  Timer? _timer;
  int _recordDuration = 0;
  String? _lastRecordedPath;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  // 1. 녹음 타이머 시작
  void _startTimer() {
    _recordDuration = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() {
        _recordDuration++;
      });
    });
  }

  // 2. 타이머 일시정지 / 재개 / 중지
  void _pauseTimer() => _timer?.cancel();
  
  void _resumeTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() {
        _recordDuration++;
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _recordDuration = 0;
    });
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  // 3. 마이크 권한 요청 및 녹음 시작
Future<void> _startRecording() async {
  try {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      _showSnackBar('마이크 접근 권한이 거부되었습니다.', isError: true);
      return;
    }

    if (await _audioRecorder.hasPermission()) {
      String path = '';

      // 웹 환경이 아닐 때만(Android/iOS/Desktop) 파일 경로 지정
      if (!kIsWeb) {
        final Directory appDocDir = await getApplicationDocumentsDirectory();
        path = '${appDocDir.path}/lecture_${DateTime.now().millisecondsSinceEpoch}.m4a';
      }

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path, // 웹일 때는 빈 문자열('') 전달 -> 인메모리/웹 전용 버퍼 처리
      );

      _startTimer();
      setState(() {
        _isRecording = true;
        _isPaused = false;
      });
    }
  } catch (e) {
    _showSnackBar('녹음을 시작하는 중 오류가 발생했습니다: $e', isError: true);
  }
}

  // 4. 녹음 일시정지 / 재개
  Future<void> _togglePauseRecording() async {
    if (_isPaused) {
      await _audioRecorder.resume();
      _resumeTimer();
      setState(() {
        _isPaused = false;
      });
    } else {
      await _audioRecorder.pause();
      _pauseTimer();
      setState(() {
        _isPaused = true;
      });
    }
  }

  // 5. 녹음 종료 및 저장
  Future<void> _stopRecording() async {
  try {
    final path = await _audioRecorder.stop();
    _stopTimer();

    setState(() {
      _isRecording = false;
      _isPaused = false;
      _lastRecordedPath = path;
    });

    if (path != null) {
      _showSnackBar('녹음이 저장되었습니다. 백엔드로 전송을 준비합니다.');
      // 여기서 필요 시 _apiService.uploadAudioAndAnalyze(...) 호출 가능!
    }
  } catch (e) {
    _showSnackBar('녹음 중지 중 오류가 발생했습니다: $e', isError: true);
  }
}

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : Colors.indigo.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('실시간 강의 녹음', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 녹음 타이머 메인 UI
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording
                    ? (_isPaused ? Colors.amber.shade50 : Colors.red.shade50)
                    : Colors.indigo.shade50,
                border: Border.all(
                  color: _isRecording
                      ? (_isPaused ? Colors.amber : Colors.red)
                      : Colors.indigo,
                  width: 4,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isRecording
                        ? (_isPaused ? Icons.pause_circle : Icons.mic)
                        : Icons.mic_none,
                    size: 64,
                    color: _isRecording
                        ? (_isPaused ? Colors.amber.shade800 : Colors.red)
                        : Colors.indigo,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _formatDuration(_recordDuration),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: _isRecording ? Colors.black87 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isRecording
                  ? (_isPaused ? '⏸️ 녹음이 일시정지되었습니다.' : '🎙️ 강의 내용을 녹음하는 중입니다...')
                  : '하단 녹음 버튼을 눌러 강의 녹음을 시작하세요.',
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 40),

            // 녹음 제어 버튼 영역
            if (!_isRecording) ...[
              ElevatedButton.icon(
                onPressed: _startRecording,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                icon: const Icon(Icons.fiber_manual_record, color: Colors.red),
                label: const Text('녹음 시작', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _togglePauseRecording,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                    label: Text(_isPaused ? '재개' : '일시정지'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _stopRecording,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    icon: const Icon(Icons.stop),
                    label: const Text('녹음 중지 및 저장', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],

            // 최근 녹음된 파일 정보 표시 카드
            if (_lastRecordedPath != null && !_isRecording) ...[
              const SizedBox(height: 40),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.audiotrack, color: Colors.indigo),
                  title: const Text('최근 녹음 파일 저장됨', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    _lastRecordedPath!.split('/').last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.check_circle, color: Colors.green),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}