import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vosk_flutter/vosk_flutter.dart';
import 'package:record/record.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JarvisApp());
}

class JarvisApp extends StatefulWidget {
  const JarvisApp({super.key});

  @override
  State<JarvisApp> createState() => _JarvisAppState();
}

class _JarvisAppState extends State<JarvisApp> {
  late FlutterTts _tts;
  final _vosk = VoskFlutterPlugin.instance();

  Model? _model;
  Recognizer? _recognizer;
  final _recorder = AudioRecorder();
  bool _isListening = false;
  bool _isLoadingModel = true;
  String? _modelError;

  final chromePath =
      r'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
  final telegramPath =
      r'C:\\Users\\User757\\AppData\\Roaming\\Telegram Desktop\\Telegram.exe';
  final vscodePath = r'D:\\VS Code app\\Microsoft VS Code\\Code.exe';
  final studioPath = r'D:\\Android Studio App\\bin\\studio64.exe';

  @override
  void initState() {
    super.initState();
    _setupTTS();
    _loadModel();
  }

  @override
  void dispose() {
    // Best-effort cleanup
    _recorder.cancel();
    _recorder.dispose();
    super.dispose();
  }

  void _setupTTS() async {
    _tts = FlutterTts();
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.9);
  }

  Future<void> _loadModel() async {
    try {
      // For desktop (Windows/Linux), load a zipped model from the network
      // and create a recognizer. This avoids asset packaging issues.
      const modelUrl =
          'https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip';

      final modelPath = await ModelLoader().loadFromNetwork(modelUrl);
      final model = await _vosk.createModel(modelPath);
      final recognizer = await _vosk.createRecognizer(
        model: model,
        sampleRate: 16000,
        grammar: const [
          'open chrome',
          'open telegram',
          'open code',
          'open vs code',
          'open studio',
          'open android studio',
          'shutdown',
          'what time is it',
        ],
      );

      setState(() {
        _model = model;
        _recognizer = recognizer;
        _isLoadingModel = false;
      });
      _startListening();
    } catch (e) {
      setState(() {
        _modelError = e.toString();
        _isLoadingModel = false;
      });
    }
  }

  // Note: On Windows/Linux the plugin does not capture the microphone.
  // Use a mic capture plugin and feed PCM data to _recognizer.acceptWaveform*.
  void _processCommand(String cmd) {
    if (cmd.contains('open chrome')) {
      Process.start(chromePath, []);
      _tts.speak('Opening Chrome');
    } else if (cmd.contains('open telegram')) {
      Process.start(telegramPath, []);
      _tts.speak('Opening Telegram');
    } else if (cmd.contains('open code') || cmd.contains('open vs code')) {
      Process.start(vscodePath, []);
      _tts.speak('Opening Visual Studio Code');
    } else if (cmd.contains('open studio') ||
        cmd.contains('open android studio')) {
      Process.start(studioPath, []);
      _tts.speak('Opening Android Studio');
    } else if (cmd.contains('shutdown')) {
      _tts.speak('Shutting down');
      Process.run('shutdown', ['/s']);
    } else if (cmd.contains('what time is it')) {
      final now = DateTime.now();
      _tts.speak(
        'Time is ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
      );
    }
  }

  Future<void> _startListening() async {
    final recognizer = _recognizer;
    if (recognizer == null) return;

    try {
      final hasPerm = await _recorder.hasPermission();
      if (!hasPerm) {
        setState(() => _modelError = 'Microphone permission denied');
        return;
      }

      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          // Smaller buffer gives lower latency; platform may override.
          streamBufferSize: 8192,
        ),
      );

      setState(() => _isListening = true);

      // Feed PCM bytes into Vosk, parse results, and act on finalized text.
      stream.listen((bytes) async {
        try {
          final isResultReady = await recognizer.acceptWaveformBytes(bytes);
          final jsonStr = isResultReady
              ? await recognizer.getResult()
              : await recognizer.getPartialResult();

          final Map<String, dynamic> data = jsonStr.isNotEmpty
              ? jsonDecode(jsonStr) as Map<String, dynamic>
              : const {};

          final text = (data['text'] ?? data['partial'] ?? '').toString();
          if (text.isEmpty) return;

          if (isResultReady) {
            _processCommand(text.toLowerCase());
          }
        } catch (_) {}
      });
    } catch (e) {
      setState(() => _modelError = 'Mic error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: _isLoadingModel
              ? const Text(
                  'Loading Vosk model...',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                )
              : _modelError != null
              ? Text(
                  'Vosk load failed: $_modelError',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 18),
                  textAlign: TextAlign.center,
                )
              : Text(
                  _isListening
                      ? 'Listening (Offline Vosk)'
                      : 'Ready (mic not started)',
                  style: const TextStyle(color: Colors.white, fontSize: 28),
                ),
        ),
      ),
    );
  }
}
