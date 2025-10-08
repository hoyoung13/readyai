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
    required this.gazeDirection,
    required this.feedback,
  });

  final HeadPose headPose;
  final GazeDirection gazeDirection;
  final String feedback;

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
      'returnFaceAttributes': 'headPose',
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
    if (headPoseData == null) {
      throw FaceAnalysisException('시선 데이터가 응답에 포함되지 않았습니다.');
    }

    final headPose = HeadPose(
      pitch: (headPoseData['pitch'] as num?)?.toDouble() ?? 0,
      roll: (headPoseData['roll'] as num?)?.toDouble() ?? 0,
      yaw: (headPoseData['yaw'] as num?)?.toDouble() ?? 0,
    );
    final gazeDirection = _interpretGaze(headPose);

    return FaceAnalysisResult(
      headPose: headPose,
      gazeDirection: gazeDirection,
      feedback: _buildGazeFeedback(headPose, gazeDirection),    );
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
  String _buildGazeFeedback(HeadPose headPose, GazeDirection direction) {
    final yaw = headPose.yaw;
    final pitch = headPose.pitch;
    final maxTilt = [yaw.abs(), pitch.abs()].reduce((a, b) => a > b ? a : b);

    switch (direction) {
      case GazeDirection.forward:
        if (maxTilt < _gazeThreshold / 2) {
          return '정면을 안정적으로 바라보며 면접에 집중하는 모습이에요.';
        }
        return '대체로 정면을 바라봤지만 시선이 살짝 흔들렸어요. 카메라를 조금 더 안정적으로 응시해 보세요.';
      case GazeDirection.left:
        if (maxTilt > _gazeThreshold * 2) {
          return '시선이 자주 왼쪽으로 크게 치우쳐 집중도가 떨어져 보여요. 답변할 때는 정면을 바라보는 연습이 필요해요.';
        }
        return '시선이 왼쪽으로 자주 이동했어요. 답변 중에도 면접관을 바라보는 습관을 들이면 더 신뢰감을 줄 수 있어요.';
      case GazeDirection.right:
        if (maxTilt > _gazeThreshold * 2) {
          return '시선이 계속 오른쪽에 머물러 면접관과의 눈맞춤이 부족해 보여요. 정면 응시를 더 의식해 보세요.';
        }
        return '시선이 오른쪽으로 자주 향했어요. 말할 때 카메라나 면접관을 다시 바라보는 연습이 필요해요.';
      case GazeDirection.up:
        if (maxTilt > _gazeThreshold * 2) {
          return '답변하는 동안 위쪽을 바라보는 시간이 길었어요. 생각이 나지 않더라도 정면을 바라보며 답변하면 집중력이 좋아 보여요.';
        }
        return '답변을 떠올리며 위를 보는 모습이 있었어요. 정면을 바라보며 자연스럽게 말하는 연습을 해보면 좋아요.';
      case GazeDirection.down:
        if (maxTilt > _gazeThreshold * 2) {
          return '고개가 아래로 많이 숙여져 자신감이 부족해 보일 수 있어요. 시선을 들어 정면을 바라보면 더 당당해 보여요.';
        }
        return '시선이 아래로 자주 향했어요. 답변할 때 고개를 들고 면접관을 바라보는 습관을 들이면 좋아요.';
    }
  }
}
