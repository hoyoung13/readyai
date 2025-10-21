import 'dart:convert';

import 'package:dio/dio.dart';

import 'job_posting.dart';

class JobInterviewQuestionService {
  JobInterviewQuestionService({
    Dio? dio,
    String? baseUrl,
    String? apiKey,
    String? model,
    this.questionCount = 5,
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
                defaultValue: 'gpt-4o-mini');

  final Dio _dio;
  final String _baseUrl;
  final String _apiKey;
  final String _model;
  final int questionCount;

  Future<List<String>> generateQuestions(JobPosting job) async {
    if (_apiKey.isEmpty) {
      throw const JobInterviewQuestionException('면접 질문 생성 API 키가 설정되지 않았습니다.');
    }

    final endpoint = '$_baseUrl/chat/completions';
    final requestBody = <String, dynamic>{
      'model': _model,
      'temperature': 0.6,
      'messages': [
        {
          'role': 'system',
          'content':
              '너는 채용공고 기반으로 심층 면접 질문을 작성하는 HR 전문가야. 항상 한국어로 질문을 작성하고, 각 질문은 한 문장으로 명확해야 해.'
        },
        {
          'role': 'user',
          'content': '''
채용공고 정보를 바탕으로 실제 면접에서 활용할 ${questionCount}개의 질문을 만들어 주세요.
각 질문은 지원자가 직무 역량, 회사 이해도, 협업 능력을 드러낼 수 있도록 구성해야 합니다.

회사명: ${job.companyLabel}
직무: ${job.title}
근무지역: ${job.regionLabel}
공고게시일: ${job.prettyPostedDate ?? job.postedDateText}
상세 링크: ${job.url}

응답은 JSON 형식으로만 반환하고, 다음 스키마를 따라 주세요.
'''
        },
      ],
      'response_format': {
        'type': 'json_schema',
        'json_schema': {
          'name': 'JobInterviewQuestions',
          'schema': {
            'type': 'object',
            'additionalProperties': false,
            'properties': {
              'questions': {
                'type': 'array',
                'items': {'type': 'string'},
                'minItems': 3,
                'maxItems': questionCount,
              }
            },
            'required': ['questions']
          }
        }
      }
    };

    final headers = <String, String>{
      Headers.contentTypeHeader: 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        endpoint,
        data: requestBody,
        options: Options(headers: headers),
      );

      final data = response.data;
      if (data == null) {
        throw const JobInterviewQuestionException('면접 질문을 생성하지 못했습니다.');
      }

      dynamic payload = data['choices']?[0]?['message']?['parsed'];
      payload ??= data['choices']?[0]?['message']?['content'];

      Map<String, dynamic> json;
      if (payload is String) {
        json = jsonDecode(payload) as Map<String, dynamic>;
      } else if (payload is Map<String, dynamic>) {
        json = payload;
      } else {
        throw const JobInterviewQuestionException('면접 질문 응답 형식이 올바르지 않습니다.');
      }

      final questions = (json['questions'] as List?)
              ?.whereType<String>()
              .map((question) => question.trim())
              .where((question) => question.isNotEmpty)
              .toList(growable: false) ??
          const <String>[];

      if (questions.isEmpty) {
        throw const JobInterviewQuestionException('면접 질문을 생성하지 못했습니다.');
      }

      return questions.length > questionCount
          ? questions.sublist(0, questionCount)
          : questions;
    } on DioException catch (error) {
      final message = error.message ?? '면접 질문 생성 중 오류가 발생했습니다.';
      throw JobInterviewQuestionException(message, cause: error);
    } on JobInterviewQuestionException {
      rethrow;
    } catch (error) {
      throw JobInterviewQuestionException(
        '면접 질문 생성 중 알 수 없는 오류가 발생했습니다.',
        cause: error,
      );
    }
  }
}

class JobInterviewQuestionException implements Exception {
  const JobInterviewQuestionException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() {
    if (cause == null) {
      return 'JobInterviewQuestionException: $message';
    }
    return 'JobInterviewQuestionException: $message (cause: $cause)';
  }
}
