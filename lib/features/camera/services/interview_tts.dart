import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

abstract class InterviewTts {
  Future<void> init();
  Future<void> speak(String text);
  Future<void> stop();
  Future<void> dispose();
}

class AndroidNativeInterviewTts implements InterviewTts {
  AndroidNativeInterviewTts();

  static const MethodChannel _channel = MethodChannel('ai/interview_audio');
  bool _ready = false;

  @override
  Future<void> init() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('initTts');
    _ready = true;
  }

  @override
  Future<void> speak(String text) async {
    if (!Platform.isAndroid || !_ready) return;
    await _channel.invokeMethod('speakText', {'text': text});
  }

  @override
  Future<void> stop() async {
    if (!Platform.isAndroid || !_ready) return;
    await _channel.invokeMethod('stopTts');
  }

  @override
  Future<void> dispose() async {
    if (!Platform.isAndroid || !_ready) return;
    await _channel.invokeMethod('shutdownTts');
    _ready = false;
  }
}

class FlutterPluginInterviewTts implements InterviewTts {
  FlutterPluginInterviewTts();

  final FlutterTts _tts = FlutterTts();

  @override
  Future<void> init() async {
    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    // The Flutter TTS plugin does not currently expose Android audio attributes
    // in this version. Android builds use the native channel implementation
    // (see createInterviewTts), so we only apply the basic configuration here
    // for non-Android platforms.
  }

  @override
  Future<void> speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }

  @override
  Future<void> dispose() async {
    await _tts.stop();
  }
}

InterviewTts createInterviewTts() {
  if (Platform.isAndroid) {
    return AndroidNativeInterviewTts();
  }
  return FlutterPluginInterviewTts();
}
