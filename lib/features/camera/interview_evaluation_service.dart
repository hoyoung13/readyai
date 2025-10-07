import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:ai/features/camera/interview_models.dart';

/// OpenAI로 면접 답변 평가
class InterviewEvaluationService {
  InterviewEvaluationService({
    Dio? dio,
    String? baseUrl,
    String? apiKey,
    String? model,
    String? organization, // 선택
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 60),
              ),
            ),
        _baseUrl = baseUrl ??
            const String.fromEnvironment(
              'EVALUATION_BASE_URL',
              defaultValue: 'https://api.openai.com/v1',
            ),
        _apiKey = apiKey ??
            const String.fromEnvironment('OPENAI_API_KEY', defaultValue: ''),
        _model = model ??
            const String.fromEnvironment('OPENAI_MODEL',
                defaultValue: 'gpt-4o-mini'),
        _organization = organization ??
            const String.fromEnvironment('OPENAI_ORG', defaultValue: '');

  final Dio _dio;
  final String _baseUrl;
  final String _apiKey;
  final String _model;
  final String _organization;

  Future<InterviewScore> evaluateInterview({
    required String transcript,
    required InterviewCameraArgs args,
  }) async {
    if (transcript.trim().isEmpty) {
      throw InterviewEvaluationException('평가할 전사 내용이 비어 있습니다.');
    }
    if (_apiKey.isEmpty) {
      throw InterviewEvaluationException('평가 API 키가 설정되지 않았습니다.');
    }

    // OpenAI Chat Completions endpoint
    final endpoint = '$_baseUrl/chat/completions';

    // 안정적 파싱을 위해 JSON Schema 강제 (OpenAI의 response_format 사용)
    final requestBody = <String, dynamic>{
      'model': _model,
      'temperature': 0.2,
      'messages': [
        {
          'role': 'system',
          'content':
              'You are an expert interview evaluator. Score answers concisely and fairly. '
                  'Return ONLY the JSON that matches the provided schema.'
        },
        {
          'role': 'user',
          'content': '''
Evaluate the following interview answer.

Category: ${args.category.title}
Mode: ${args.mode.title}

Transcript:
"""${_truncate(transcript, 6000)}"""
'''
        },
      ],
      // json_schema 출력 (OpenAI 2024+ 지원)
      'response_format': {
        'type': 'json_schema',
        'json_schema': {
          'name': 'InterviewEvaluation',
          'schema': {
            'type': 'object',
            'additionalProperties': false,
            'properties': {
              'overallScore': {
                'type': 'number',
                'minimum': 0,
                'maximum': 100,
                'description': 'Overall score from 0 to 100'
              },
              'feedback': {
                'type': 'array',
                'items': {
                  'type': 'object',
                  'additionalProperties': false,
                  'properties': {
                    'question': {'type': 'string'},
                    'feedback': {'type': 'string'},
                    'score': {
                      'type': ['number', 'null'],
                      'minimum': 0,
                      'maximum': 100
                    }
                  },
                  'required': ['feedback']
                }
              }
            },
            'required': ['overallScore', 'feedback']
          }
        }
      }
    };

    final headers = <String, String>{
      HttpHeaders.authorizationHeader: 'Bearer $_apiKey',
      Headers.contentTypeHeader: 'application/json',
      if (_organization.isNotEmpty) 'OpenAI-Organization': _organization,
    };

    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        endpoint,
        data: requestBody,
        options: Options(headers: headers),
      );

      final data = resp.data;
      if (data == null) {
        throw InterviewEvaluationException('평가 결과를 받지 못했습니다.');
      }

      // 1) json_schema 사용 시 parsed가 들어오기도 함
      dynamic payload =
          data['choices']?[0]?['message']?['parsed']; // already object
      // 2) 아니면 content에 문자열 JSON으로 옴
      payload ??= data['choices']?[0]?['message']?['content'];

      Map<String, dynamic> json;
      if (payload is String) {
        json = jsonDecode(payload) as Map<String, dynamic>;
      } else if (payload is Map<String, dynamic>) {
        json = payload;
      } else {
        throw InterviewEvaluationException('평가 응답 형식이 올바르지 않습니다.');
      }

      final overall = (json['overallScore'] as num?)?.toDouble();
      if (overall == null) {
        throw InterviewEvaluationException('평가 점수가 포함되어 있지 않습니다.');
      }

      final feedbackList = (json['feedback'] as List?) ?? const [];
      final perQuestion = feedbackList
          .whereType<Map<String, dynamic>>()
          .map((m) => QuestionFeedback(
                question: (m['question'] as String?)?.trim() ?? '',
                feedback: (m['feedback'] as String?)?.trim() ?? '',
                score:
                    (m['score'] is num) ? (m['score'] as num).toDouble() : null,
              ))
          .where((f) => f.feedback.isNotEmpty || f.question.isNotEmpty)
          .toList();

      return InterviewScore(
        overallScore: overall.clamp(0, 100),
        perQuestionFeedback: perQuestion,
      );
    } on DioException catch (e) {
      throw InterviewEvaluationException(_mapDioErrorToMessage(e), cause: e);
    } catch (e) {
      if (e is InterviewEvaluationException) rethrow;
      throw InterviewEvaluationException('면접 평가 처리 중 오류가 발생했습니다.', cause: e);
    }
  }

  String _mapDioErrorToMessage(DioException error) {
    final code = error.response?.statusCode;
    if (error.type == DioExceptionType.badResponse) {
      if (code == 401 || code == 403) {
        return '평가 서비스 인증에 실패했습니다. API 키를 확인해 주세요.';
      }
      if (code == 429) {
        return '요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.';
      }
      return '평가 요청이 실패했습니다. (HTTP $code)';
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return '평가 서버와 통신하지 못했습니다. 네트워크 상태를 확인해 주세요.';
      case DioExceptionType.cancel:
        return '평가 요청이 취소되었습니다. 다시 시도해 주세요.';
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return '면접 평가 중 알 수 없는 오류가 발생했습니다.';
      default:
        return '면접 평가 처리 중 오류가 발생했습니다.';
    }
  }
}

class InterviewEvaluationException implements Exception {
  InterviewEvaluationException(this.message, {this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'InterviewEvaluationException: $message'
      : 'InterviewEvaluationException: $message (cause: $cause)';
}

// 긴 transcript 안전 트렁케이션(토큰 폭주 방지)
String _truncate(String s, int max) {
  if (s.length <= max) return s;
  return s.substring(0, max) + ' ...';
}
