import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

typedef SttProgressCallback = void Function(String message);

class InterviewSttService {
  InterviewSttService({
    Dio? dio,
    String? baseUrl,
    String? apiKey,
    int maxRetries = 3,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 60),
              ),
            ),
        _baseUrl = baseUrl ??
            const String.fromEnvironment('STT_BASE_URL',
                defaultValue: 'https://api.example.com'),
        _apiKey = apiKey ??
            const String.fromEnvironment('STT_API_KEY', defaultValue: ''),
        _maxRetries = maxRetries;

  final Dio _dio;
  final String _baseUrl;
  final String _apiKey;
  final int _maxRetries;

  Future<String> transcribeVideo({
    required String videoPath,
    SttProgressCallback? onProgress,
  }) async {
    if (_apiKey.isEmpty) {
      throw InterviewSttException('STT API 키가 설정되지 않았습니다.');
    }

    final videoFile = File(videoPath);
    if (!await videoFile.exists()) {
      throw InterviewSttException('녹화된 파일을 찾을 수 없습니다.');
    }

    onProgress?.call('오디오를 준비하는 중...');
    final audioFile = await _prepareAudioFile(videoFile);

    onProgress?.call('음성을 전사하는 중...');
    final endpoint = '$_baseUrl/transcriptions';
    final options = Options(
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer $_apiKey',
        Headers.contentTypeHeader: 'multipart/form-data',
      },
    );

    DioException? lastError;
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            audioFile.path,
            filename: audioFile.uri.pathSegments.last,
          ),
        });

        final response = await _dio.post<Map<String, dynamic>>(
          endpoint,
          data: formData,
          options: options,
        );

        final data = response.data;
        final transcript = data?['transcript'] as String?;
        if (transcript == null || transcript.isEmpty) {
          throw InterviewSttException('전사 결과를 가져오지 못했습니다.');
        }

        return transcript;
      } on DioException catch (error) {
        lastError = error;
        if (attempt == _maxRetries - 1) {
          break;
        }
        onProgress?.call('전사를 다시 시도하는 중...');
        await Future<void>.delayed(Duration(seconds: 1 << attempt));
      }
    }

    throw InterviewSttException(
      '음성 인식 서버와 통신하지 못했습니다.',
      cause: lastError,
    );
  }

  Future<File> _prepareAudioFile(File videoFile) async {
    final extension = videoFile.path.split('.').last.toLowerCase();
    const acceptedAudioExtensions = ['mp3', 'wav', 'm4a', 'aac'];
    if (acceptedAudioExtensions.contains(extension)) {
      return videoFile;
    }

    // 많은 STT 서비스가 MP4/WEBM 비디오를 그대로 처리할 수 있으므로
    // 기본적으로는 원본 파일을 그대로 반환합니다. 필요하다면
    // ffmpeg 등의 툴을 이용해 오디오 트랙만 추출하도록 확장할 수 있습니다.
    return videoFile;
  }
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