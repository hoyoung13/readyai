import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:ai/features/camera/interview_models.dart';

class InterviewEvaluationService {
  InterviewEvaluationService({
    Dio? dio,
    String? baseUrl,
    String? apiKey,
    String? model,
    String? organization,
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

    final endpoint = '$_baseUrl/chat/completions';
    final questions = args.questions;
    final questionSection = questions.isEmpty
        ? '질문이 별도로 제공되지 않았습니다.'
        : questions
            .asMap()
            .entries
            .map((entry) => '${entry.key + 1}. ${entry.value}')
            .join('\n');

    final requestBody = <String, dynamic>{
      'model': _model,
      'temperature': 0.2,
      'messages': [
        {
          'role': 'system',
          'content':
              '너는 면접관 역할의 전문가 평가자입니다. 항상 한국어로 평가하세요. '
              '제공된 질문 목록을 기준으로 면접 답변을 객관적이고 간결하게 평가하고, 각 질문에 대한 피드백과 점수를 생성하세요. '
              '반드시 질문 순서를 유지하고, 질문 텍스트는 제공된 문장을 그대로 사용하세요. '
              '주어진 JSON 스키마 형식에 맞게 결과를 반환하세요. 평가 결과의 모든 텍스트(피드백, 질문 등)는 반드시 한국어로 작성해야 합니다. '
              'JSON 외의 추가 텍스트는 절대 포함하지 마세요.'
        },
        {
          'role': 'user',
          'content': '''
Evaluate the following interview answer.

Category: ${args.category.title}
Mode: ${args.mode.title}

Questions:
$questionSection

Transcript:
"""${_truncate(transcript, 6000)}"""
'''
        },
      ],
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
                  'required': ['question', 'feedback']
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

      dynamic payload = data['choices']?[0]?['message']?['parsed'];

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
      List<QuestionFeedback> perQuestion = feedbackList
          .whereType<Map<String, dynamic>>()
          .map((m) => QuestionFeedback(
                question: (m['question'] as String?)?.trim() ?? '',
                feedback: (m['feedback'] as String?)?.trim() ?? '',
                score:
                    (m['score'] is num) ? (m['score'] as num).toDouble() : null,
              ))
          .where((f) => f.feedback.isNotEmpty || f.question.isNotEmpty)
          .toList();
          if (questions.isNotEmpty) {
        perQuestion = List.generate(questions.length, (index) {
          if (index < perQuestion.length) {
            final item = perQuestion[index];
            return QuestionFeedback(
              question: questions[index],
              feedback: item.feedback,
              score: item.score,
            );
          }
          return QuestionFeedback(
            question: questions[index],
            feedback: '해당 질문에 대한 답변이 명확하지 않아 평가할 수 없습니다.',
            score: null,
          );
        });
      }

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
