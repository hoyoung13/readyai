import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class FaceAnalysisException implements Exception {
  FaceAnalysisException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'FaceAnalysisException(message: $message, cause: $cause)';
}

class HeadPose {
  const HeadPose({
    required this.pitch,
    required this.roll,
    required this.yaw,
  });

  final double pitch;
  final double roll;
  final double yaw;
}

class EmotionScore {
  const EmotionScore(this.label, this.probability);

  final String label;
  final double probability;
}

enum GazeDirection {
  forward('정면 응시'),
  left('왼쪽을 보고 있음'),
  right('오른쪽을 보고 있음'),
  up('위를 보고 있음'),
  down('아래를 보고 있음');

  const GazeDirection(this.label);

  final String label;
}

class FaceAnalysisResult {
  const FaceAnalysisResult({
    required this.headPose,
    required this.dominantEmotion,
    required this.emotions,
    required this.gazeDirection,
  });

  final HeadPose headPose;
  final EmotionScore dominantEmotion;
  final List<EmotionScore> emotions;
  final GazeDirection gazeDirection;
}

class AzureFaceAnalysisService {
  AzureFaceAnalysisService({
    http.Client? httpClient,
    String? endpoint,
    String? apiKey,
    Duration? requestTimeout,
    double? gazeThreshold,
  })  : _client = httpClient ?? http.Client(),
        _endpoint = endpoint ??
            const String.fromEnvironment('AZURE_FACE_ENDPOINT',
                defaultValue: ''),
        _apiKey = apiKey ??
            const String.fromEnvironment('AZURE_FACE_KEY', defaultValue: ''),
        _requestTimeout = requestTimeout ?? const Duration(seconds: 30),
        _gazeThreshold = gazeThreshold ?? 10.0;

  final http.Client _client;
  final String _endpoint;
  final String _apiKey;
  final Duration _requestTimeout;
  final double _gazeThreshold;

  Future<FaceAnalysisResult> analyzeVideo(String videoPath) async {
    final videoFile = File(videoPath);
    if (!await videoFile.exists()) {
      throw FaceAnalysisException('분석할 녹화 파일을 찾을 수 없습니다.');
    }

    final frameBytes = await _extractFrame(videoFile);
    return analyzeImageBytes(frameBytes);
  }

  Future<FaceAnalysisResult> analyzeImageBytes(Uint8List imageBytes) async {
    if (_endpoint.isEmpty || _apiKey.isEmpty) {
      throw FaceAnalysisException(
        'Azure Face API 엔드포인트 또는 키가 설정되지 않았습니다.',
      );
    }

    final uri =
        Uri.parse('$_endpoint/face/v1.0/detect').replace(queryParameters: {
      'returnFaceId': 'false',
      'returnFaceAttributes': 'headPose,emotion',
      'detectionModel': 'detection_03',
      'faceIdTimeToLive': '60',
    });

    late http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'Ocp-Apim-Subscription-Key': _apiKey,
              'Content-Type': 'application/octet-stream',
            },
            body: imageBytes,
          )
          .timeout(_requestTimeout);
    } on TimeoutException catch (error) {
      throw FaceAnalysisException('Azure Face API 응답이 지연되고 있습니다.',
          cause: error);
    } on SocketException catch (error) {
      throw FaceAnalysisException('Azure Face API와 통신할 수 없습니다.', cause: error);
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw FaceAnalysisException('Azure Face API 인증에 실패했습니다. 설정을 확인해 주세요.');
    }

    if (response.statusCode != 200) {
      throw FaceAnalysisException(
        'Azure Face API 호출이 실패했습니다. (HTTP ${response.statusCode})',
        cause: response.body,
      );
    }

    final List<dynamic> payload = jsonDecode(response.body) as List<dynamic>;
    if (payload.isEmpty) {
      throw FaceAnalysisException('영상에서 얼굴을 찾을 수 없습니다.');
    }

    final data = payload.first as Map<String, dynamic>;
    final attributes = data['faceAttributes'] as Map<String, dynamic>?;
    if (attributes == null) {
      throw FaceAnalysisException('얼굴 속성 데이터가 포함되어 있지 않습니다.');
    }

    final headPoseData = attributes['headPose'] as Map<String, dynamic>?;
    final emotionData = attributes['emotion'] as Map<String, dynamic>?;

    if (headPoseData == null || emotionData == null) {
      throw FaceAnalysisException('시선 또는 감정 데이터가 응답에 포함되지 않았습니다.');
    }

    final headPose = HeadPose(
      pitch: (headPoseData['pitch'] as num?)?.toDouble() ?? 0,
      roll: (headPoseData['roll'] as num?)?.toDouble() ?? 0,
      yaw: (headPoseData['yaw'] as num?)?.toDouble() ?? 0,
    );

    final emotions = emotionData.entries
        .where((entry) => entry.value is num)
        .map(
          (entry) => EmotionScore(
            entry.key,
            (entry.value as num).toDouble(),
          ),
        )
        .toList()
      ..sort((a, b) => b.probability.compareTo(a.probability));

    if (emotions.isEmpty) {
      throw FaceAnalysisException('감정 분석 결과가 비어 있습니다.');
    }

    return FaceAnalysisResult(
      headPose: headPose,
      dominantEmotion: emotions.first,
      emotions: emotions,
      gazeDirection: _interpretGaze(headPose),
    );
  }

  Future<Uint8List> _extractFrame(File videoFile) async {
    final tempDir = await getTemporaryDirectory();
    final outputPath = p.join(
      tempDir.path,
      '${p.basenameWithoutExtension(videoFile.path)}_thumb_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    final args = <String>[
      '-y',
      '-i',
      videoFile.path,
      '-vf',
      'select=eq(pict_type\\,I)',
      '-frames:v',
      '1',
      outputPath,
    ];

    final session = await FFmpegKit.executeWithArguments(args);
    final returnCode = await session.getReturnCode();
    if (!ReturnCode.isSuccess(returnCode)) {
      throw FaceAnalysisException(
        '녹화 영상에서 이미지를 추출하지 못했습니다. (code: ${returnCode?.getValue() ?? -1})',
      );
    }

    final file = File(outputPath);
    if (!await file.exists()) {
      throw FaceAnalysisException('추출된 이미지 파일을 찾을 수 없습니다.');
    }

    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw FaceAnalysisException('추출된 이미지 데이터가 비어 있습니다.');
      }
      return bytes;
    } finally {
      unawaited(_safeDelete(file));
    }
  }

  Future<void> _safeDelete(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  GazeDirection _interpretGaze(HeadPose headPose) {
    final yaw = headPose.yaw;
    final pitch = headPose.pitch;

    if (yaw.abs() < _gazeThreshold && pitch.abs() < _gazeThreshold) {
      return GazeDirection.forward;
    }
    if (yaw > _gazeThreshold) {
      return GazeDirection.right;
    }
    if (yaw < -_gazeThreshold) {
      return GazeDirection.left;
    }
    if (pitch > _gazeThreshold) {
      return GazeDirection.up;
    }
    return GazeDirection.down;
  }
}
