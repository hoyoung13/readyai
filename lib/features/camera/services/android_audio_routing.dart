import 'dart:io';

import 'package:flutter/services.dart';

/// Android 전용 오디오 라우팅 헬퍼.
///
/// - 녹화 시작 전에 [prepareForInterviewRecording]을 호출해 마이크 전용 모드로 전환
/// - 녹화 종료 후 [restoreAudio]로 원래 오디오 상태 복구
class AndroidAudioRouting {
  const AndroidAudioRouting._();

  static const MethodChannel _channel = MethodChannel('ai/interview_audio');

  static Future<void> prepareForInterviewRecording() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('prepareAudio');
    } on PlatformException {
      // 녹화는 계속 진행되도록 예외를 삼킨다.
    }
  }

  static Future<void> restoreAudio() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('restoreAudio');
    } on PlatformException {
      // 복구 실패 시에도 앱이 죽지 않도록 처리
    }
  }
}
