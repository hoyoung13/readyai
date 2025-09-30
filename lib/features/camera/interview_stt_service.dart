import 'dart:async';
import 'dart:io';
import 'package:ai/features/camera/services/google_cloud_stt_service.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/media_information.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/stream_information.dart';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

typedef SttProgressCallback = void Function(String message);

class InterviewTranscription {
  const InterviewTranscription({required this.text, this.confidence});

  final String text;
  final double? confidence;
}

class InterviewSttService {
  InterviewSttService({
    GoogleCloudSttService? googleCloudSttService,
    VideoToAudioConverter? audioConverter,
  })  : _googleCloudSttService =
            googleCloudSttService ?? GoogleCloudSttService(),
        _audioConverter = audioConverter ?? const VideoToAudioConverter();

  final GoogleCloudSttService _googleCloudSttService;
  final VideoToAudioConverter _audioConverter;

  Future<InterviewTranscription> transcribeVideo({
    required String videoPath,
    SttProgressCallback? onProgress,
  }) async {
    final videoFile = File(videoPath);
    if (!await videoFile.exists()) {
      throw InterviewSttException('녹화된 파일을 찾을 수 없습니다.');
    }

    onProgress?.call('녹화된 음성을 추출하는 중...');
    AudioConversionResult conversion;
    try {
      conversion = await _audioConverter.convert(videoFile);
    } on AudioConversionException catch (error) {
      throw InterviewSttException(error.message, cause: error);
    }

    try {
      onProgress?.call('음성을 Google STT로 전송하는 중...');
      final result = await _googleCloudSttService.transcribe(
        audioFile: conversion.file,
        audioDuration: conversion.duration,
        sampleRate: conversion.sampleRate,
        onProgress: onProgress,
      );
      return InterviewTranscription(
        text: result.transcript,
        confidence: result.confidence,
      );
    } on GoogleCloudSttException catch (error) {
      throw InterviewSttException(error.message, cause: error);
    } finally {
      if (conversion.shouldDelete) {
        unawaited(_safeDelete(conversion.file));
      }
    }
  }

  Future<void> _safeDelete(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}

class AudioConversionResult {
  const AudioConversionResult({
    required this.file,
    required this.shouldDelete,
    this.duration,
    this.sampleRate,
  });

  final File file;
  final bool shouldDelete;
  final Duration? duration;
  final int? sampleRate;
}

class VideoToAudioConverter {
  const VideoToAudioConverter({
    this.sampleRate = 16000,
    this.outputExtension = 'flac',
    this.keepOutput = false,
  });

  final int sampleRate;
  final String outputExtension;
  final bool keepOutput;

  Future<AudioConversionResult> convert(File videoFile) async {
    if (!await videoFile.exists()) {
      throw const AudioConversionException('녹화된 파일을 찾을 수 없습니다.');
    }

    final tempDir = await getTemporaryDirectory();
    final outputPath = p.join(
      tempDir.path,
      '${p.basenameWithoutExtension(videoFile.path)}_${DateTime.now().millisecondsSinceEpoch}.$outputExtension',
    );

    final arguments = <String>[
      '-y',
      '-i',
      videoFile.path,
      '-vn',
      '-ac',
      '1',
      '-ar',
      '$sampleRate',
      '-sample_fmt',
      's16',
      outputPath,
    ];

    final session = await FFmpegKit.executeWithArguments(arguments);
    final returnCode = await session.getReturnCode();
    if (!ReturnCode.isSuccess(returnCode)) {
      throw AudioConversionException(
        '오디오를 추출하지 못했습니다. (code: ${returnCode?.getValue() ?? -1})',
      );
    }

    final probeSession = await FFprobeKit.getMediaInformation(outputPath);
    final mediaInformation = await probeSession.getMediaInformation();

    Duration? duration;
    int? detectedSampleRate;

    if (mediaInformation != null) {
      duration = _parseDuration(mediaInformation);
      detectedSampleRate = _parseSampleRate(mediaInformation);
    }

    return AudioConversionResult(
      file: File(outputPath),
      shouldDelete: !keepOutput,
      duration: duration,
      sampleRate: detectedSampleRate ?? sampleRate,
    );
  }

  Duration? _parseDuration(MediaInformation mediaInformation) {
    final durationString = mediaInformation.getDuration();
    if (durationString == null) {
      return null;
    }
    final seconds = double.tryParse(durationString);
    if (seconds == null) {
      return null;
    }
    return Duration(milliseconds: (seconds * 1000).round());
  }

  int? _parseSampleRate(MediaInformation mediaInformation) {
    final streams = mediaInformation.getStreams();
    if (streams == null) {
      return null;
    }
    for (final StreamInformation stream in streams) {
      if (stream.getType() == 'audio') {
        final value = stream.getSampleRate();
        if (value != null) {
          final parsed = int.tryParse(value);
          if (parsed != null) {
            return parsed;
          }
        }
      }
    }
    return null;
  }
}

class AudioConversionException implements Exception {
  const AudioConversionException(this.message);

  final String message;

  @override
  String toString() => 'AudioConversionException: $message';
}

class InterviewSttException implements Exception {
  InterviewSttException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() {
    if (cause == null) {
      return 'InterviewSttException: $message';
    }
    return 'InterviewSttException: $message (cause: $cause)';
  }
}
