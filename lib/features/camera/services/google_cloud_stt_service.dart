import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:googleapis/speech/v1.dart' as speech;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

typedef GoogleSttProgressCallback = void Function(String message);

class GoogleCloudSttResult {
  const GoogleCloudSttResult({required this.transcript, this.confidence});

  final String transcript;
  final double? confidence;
}

class RetryOptions {
  const RetryOptions({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 2),
    this.multiplier = 2.0,
    this.maxDelay = const Duration(seconds: 12),
    this.pollInterval = const Duration(seconds: 3),
  })  : assert(maxAttempts > 0),
        assert(multiplier >= 1.0);

  final int maxAttempts;
  final Duration initialDelay;
  final double multiplier;
  final Duration maxDelay;
  final Duration pollInterval;
}

class GoogleCloudSttException implements Exception {
  const GoogleCloudSttException(this.message, {this.cause, this.stackTrace});

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() {
    final buffer = StringBuffer('GoogleCloudSttException: $message');
    if (cause != null) {
      buffer.write(' (cause: $cause)');
    }
    return buffer.toString();
  }
}

/// Provides OAuth2 clients for authenticating with Google Cloud Speech-to-Text
/// without embedding secrets directly in the application bundle.
///
/// Credentials are resolved in the following order:
/// 1. A raw service-account JSON string supplied through the
///    `GOOGLE_SERVICE_ACCOUNT_JSON` compile-time environment variable.
/// 2. A file path provided via the `GOOGLE_APPLICATION_CREDENTIALS`
///    compile-time environment variable. The file can be stored securely on
///    device storage or injected at runtime.
/// 3. Application Default Credentials (for example, when running in development
///    with `gcloud auth application-default login`).
class GoogleCloudCredentialsProvider {
  const GoogleCloudCredentialsProvider({
    this.scopes = const [speech.SpeechApi.cloudPlatformScope],
    String? serviceAccountJsonPath,
    String? serviceAccountJson,
    this.allowApplicationDefault = true,
  })  : serviceAccountJsonPath =
            serviceAccountJsonPath ?? _defaultServiceAccountJsonPath,
        serviceAccountJson =
            serviceAccountJson ?? _defaultInlineServiceAccountJson;

  final List<String> scopes;
  final String? serviceAccountJsonPath;
  final String? serviceAccountJson;
  final bool allowApplicationDefault;

  static const String _defaultServiceAccountJsonPath =
      String.fromEnvironment('GOOGLE_APPLICATION_CREDENTIALS');
  static const String _defaultInlineServiceAccountJson =
      String.fromEnvironment('GOOGLE_SERVICE_ACCOUNT_JSON');

  Future<AuthClient> obtainClient(http.Client baseClient) async {
    final inlineJson = serviceAccountJson?.trim();
    if (inlineJson != null && inlineJson.isNotEmpty) {
      final credentials = ServiceAccountCredentials.fromJson(inlineJson);
      return clientViaServiceAccount(credentials, scopes,
          baseClient: baseClient);
    }

    final path = serviceAccountJsonPath?.trim();
    if (path != null && path.isNotEmpty) {
      final json = await File(path).readAsString();
      final credentials = ServiceAccountCredentials.fromJson(json);
      return clientViaServiceAccount(credentials, scopes,
          baseClient: baseClient);
    }

    if (allowApplicationDefault) {
      return clientViaApplicationDefaultCredentials(
        scopes: scopes,
        baseClient: baseClient,
      );
    }

    throw const GoogleCloudSttException('Google Cloud 인증 정보를 찾을 수 없습니다.');
  }
}

class GoogleCloudSttService {
  GoogleCloudSttService({
    http.Client? httpClient,
    GoogleCloudCredentialsProvider? credentialsProvider,
    this.languageCode = 'ko-KR',
    this.enableAutomaticPunctuation = true,
    this.model,
    this.longRunningThreshold = const Duration(minutes: 1),
    this.syncMaxFileSizeBytes = 10 * 1024 * 1024,
    RetryOptions? retryOptions,
  })  : _httpClient = httpClient ?? http.Client(),
        _credentialsProvider =
            credentialsProvider ?? const GoogleCloudCredentialsProvider(),
        _retryOptions = retryOptions ?? const RetryOptions();

  final http.Client _httpClient;
  final GoogleCloudCredentialsProvider _credentialsProvider;
  final RetryOptions _retryOptions;

  final String languageCode;
  final bool enableAutomaticPunctuation;
  final String? model;
  final Duration longRunningThreshold;
  final int syncMaxFileSizeBytes;

  Future<GoogleCloudSttResult> transcribe({
    required File audioFile,
    Duration? audioDuration,
    int? sampleRate,
    GoogleSttProgressCallback? onProgress,
  }) async {
    if (!await audioFile.exists()) {
      throw const GoogleCloudSttException('오디오 파일을 찾을 수 없습니다.');
    }

    final authClient = await _credentialsProvider.obtainClient(_httpClient);
    try {
      final speechApi = speech.SpeechApi(authClient);
      final audioBytes = await audioFile.readAsBytes();
      final audio = speech.RecognitionAudio(content: base64Encode(audioBytes));
      final config = speech.RecognitionConfig(
        encoding: speech.RecognitionConfig_AudioEncoding.flac,
        languageCode: languageCode,
        enableAutomaticPunctuation: enableAutomaticPunctuation,
        sampleRateHertz: sampleRate,
        audioChannelCount: 1,
        model: model,
      );
      final request = speech.RecognizeRequest(audio: audio, config: config);

      final useLongRunning = _shouldUseLongRunning(
        audioLengthBytes: audioBytes.length,
        duration: audioDuration,
      );

      if (useLongRunning) {
        onProgress?.call('장시간 음성을 인식하는 중...');
        final operation = await _retry(() async {
          return speechApi.speech.longrunningrecognize(request);
        });
        return _waitForOperation(
          speechApi,
          operation,
          onProgress,
        );
      }

      onProgress?.call('음성 전사를 요청하는 중...');
      final response = await _retry(() async {
        return speechApi.speech.recognize(request);
      });
      return _mapRecognizeResponse(response);
    } on GoogleCloudSttException {
      rethrow;
    } catch (error, stackTrace) {
      throw GoogleCloudSttException(
        'Google Cloud Speech-to-Text 요청 중 오류가 발생했습니다.',
        cause: error,
        stackTrace: stackTrace,
      );
    } finally {
      authClient.close();
    }
  }

  Future<GoogleCloudSttResult> _waitForOperation(
    speech.SpeechApi speechApi,
    speech.Operation operation,
    GoogleSttProgressCallback? onProgress,
  ) async {
    var currentOperation = operation;
    while (!(currentOperation.done ?? false)) {
      await Future<void>.delayed(_retryOptions.pollInterval);
      onProgress?.call('전사 결과를 기다리는 중...');
      if (currentOperation.name == null) {
        break;
      }
      currentOperation = await speechApi.operations.get(currentOperation.name!);
    }

    if (!(currentOperation.done ?? false)) {
      throw const GoogleCloudSttException(
          '전사 작업이 예상보다 오래 걸리고 있습니다. 나중에 다시 시도해 주세요.');
    }

    if (currentOperation.error != null) {
      final status = currentOperation.error!;
      throw GoogleCloudSttException(
        status.message ?? '전사 작업이 실패했습니다.',
        cause: status,
      );
    }

    final responseMap = currentOperation.response as Map<String, dynamic>?;
    if (responseMap == null) {
      throw const GoogleCloudSttException('Google Cloud에서 전사 응답을 반환하지 않았습니다.');
    }

    final response = speech.LongRunningRecognizeResponse.fromJson(responseMap);
    return _mapLongRunningResponse(response);
  }

  Future<T> _retry<T>(Future<T> Function() request) async {
    Object? lastError;
    StackTrace? lastStackTrace;
    var delay = _retryOptions.initialDelay;
    for (var attempt = 0; attempt < _retryOptions.maxAttempts; attempt++) {
      try {
        return await request();
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        if (attempt == _retryOptions.maxAttempts - 1) {
          throw GoogleCloudSttException(
            'Google Cloud STT 요청에 실패했습니다.',
            cause: error,
            stackTrace: stackTrace,
          );
        }
        await Future<void>.delayed(delay);
        delay = _increaseDelay(delay);
      }
    }

    throw GoogleCloudSttException(
      'Google Cloud STT 요청에 실패했습니다.',
      cause: lastError,
      stackTrace: lastStackTrace,
    );
  }

  bool _shouldUseLongRunning({
    required int audioLengthBytes,
    Duration? duration,
  }) {
    if (audioLengthBytes >= syncMaxFileSizeBytes) {
      return true;
    }
    if (duration != null && duration >= longRunningThreshold) {
      return true;
    }
    return false;
  }

  Duration _increaseDelay(Duration delay) {
    final scaledMilliseconds =
        (delay.inMilliseconds * _retryOptions.multiplier).round();
    final nextDelay = Duration(milliseconds: scaledMilliseconds);
    if (nextDelay > _retryOptions.maxDelay) {
      return _retryOptions.maxDelay;
    }
    return nextDelay;
  }

  GoogleCloudSttResult _mapRecognizeResponse(
      speech.RecognizeResponse response) {
    final results = response.results;
    if (results == null || results.isEmpty) {
      throw const GoogleCloudSttException('전사 결과를 찾을 수 없습니다.');
    }
    return _mapAlternatives(results.map((r) => r.alternatives ?? const []));
  }

  GoogleCloudSttResult _mapLongRunningResponse(
      speech.LongRunningRecognizeResponse response) {
    final results = response.results;
    if (results == null || results.isEmpty) {
      throw const GoogleCloudSttException('전사 결과를 찾을 수 없습니다.');
    }
    return _mapAlternatives(results.map((r) => r.alternatives ?? const []));
  }

  GoogleCloudSttResult _mapAlternatives(
    Iterable<List<speech.SpeechRecognitionAlternative>> groupedAlternatives,
  ) {
    final transcriptBuffer = StringBuffer();
    final confidences = <double>[];

    for (final alternatives in groupedAlternatives) {
      speech.SpeechRecognitionAlternative? selected;
      for (final alternative in alternatives) {
        if (selected == null ||
            (alternative.confidence ?? 0) > (selected.confidence ?? 0)) {
          selected = alternative;
        }
      }

      if (selected == null || (selected.transcript ?? '').trim().isEmpty) {
        continue;
      }
      if (transcriptBuffer.isNotEmpty) {
        transcriptBuffer.write(' ');
      }
      transcriptBuffer.write(selected.transcript!.trim());
      final confidence = selected.confidence;
      if (confidence != null) {
        confidences.add(confidence);
      }
    }

    final transcript = transcriptBuffer.toString().trim();
    if (transcript.isEmpty) {
      throw const GoogleCloudSttException('전사 텍스트가 비어 있습니다.');
    }

    final confidence = confidences.isEmpty
        ? null
        : confidences.reduce((a, b) => a + b) / confidences.length;

    return GoogleCloudSttResult(transcript: transcript, confidence: confidence);
  }
}
