import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vosk_flutter/vosk_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await VoskFlutter.init();
  runApp(const JarvisApp());
}

class JarvisApp extends StatefulWidget {
  const JarvisApp({super.key});

  @override
  State<JarvisApp> createState() => _JarvisAppState();
}

class _JarvisAppState extends State<JarvisApp> {
  late FlutterTts _tts;
  late VoskModel _model;
  late VoskRecognizer _recognizer;
  bool _isListening = false;

  final chromePath = r'C:\Program Files\Google\Chrome\Application\chrome.exe';
  final telegramPath = r'C:\Users\User757\AppData\Roaming\Telegram Desktop\Telegram.exe';
  final vscodePath = r'D:\VS Code app\Microsoft VS Code\Code.exe';
  final studioPath = r'D:\Android Studio App\bin\studio64.exe';

  @override
  void initState() {
    super.initState();
    _setupTTS();
    _loadModel();
  }

  void _setupTTS() async {
    _tts = FlutterTts();
    await _tts.setLanguage("en-US");
    await _tts.setVoice({"name": "Microsoft David", "locale": "en-US"});
    await _tts.setSpeechRate(0.9);
  }

  void _loadModel() async {
    _model = await VoskModel.fromAssets("models/vosk-model-small-en-us");
    _recognizer = VoskRecognizer(model: _model, sampleRate: 16000);
    _startMic();
  }

  void _startMic() async {
    final mic = await VoskRecorder.create();
    mic.start(onData: (text) {
      final result = _recognizer.recognize(text);
      if (result.isNotEmpty) {
        print("🎤 Recognized: $result");
        _processCommand(result.toLowerCase());
      }
    });

    setState(() => _isListening = true);
  }

  void _processCommand(String cmd) {
    if (cmd.contains("open chrome")) {
      Process.start(chromePath, []);
      _tts.speak("Opening Chrome");
    } else if (cmd.contains("open telegram")) {
      Process.start(telegramPath, []);
      _tts.speak("Opening Telegram");
    } else if (cmd.contains("open code") || cmd.contains("open vs code")) {
      Process.start(vscodePath, []);
      _tts.speak("Opening Visual Studio Code");
    } else if (cmd.contains("open studio") || cmd.contains("open android studio")) {
      Process.start(studioPath, []);
      _tts.speak("Opening Android Studio");
    } else if (cmd.contains("shutdown")) {
      _tts.speak("Shutting down");
      Process.run("shutdown", ["/s"]);
    } else if (cmd.contains("what time is it")) {
      final now = DateTime.now();
      _tts.speak("Time is ${now.hour}:${now.minute}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            _isListening ? "🎧 Listening (Offline VOSK)" : "❌ Not Listening",
            style: const TextStyle(color: Colors.white, fontSize: 28),
          ),
        ),
      ),
    );
  }
}

