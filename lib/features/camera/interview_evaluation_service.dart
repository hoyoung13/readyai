import 'dart:io';

import 'package:dio/dio.dart';
import 'package:ai/features/camera/interview_models.dart';

class InterviewEvaluationService {
  InterviewEvaluationService({
    Dio? dio,
    String? baseUrl,
    String? apiKey,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 60),
              ),
            ),
        _baseUrl = baseUrl ??
            const String.fromEnvironment(
              'EVALUATION_BASE_URL',
              defaultValue: 'https://api.example.com',
            ),
        _apiKey = apiKey ??
            const String.fromEnvironment('EVALUATION_API_KEY',
                defaultValue: '');

  final Dio _dio;
  final String _baseUrl;
  final String _apiKey;

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

    final endpoint = '$_baseUrl/interview/evaluate';
    final payload = <String, dynamic>{
      'transcript': transcript,
      'category': args.category.title,
      'mode': args.mode.name,
    };

    final options = Options(
      headers: {
        Headers.contentTypeHeader: 'application/json',
        if (_apiKey.isNotEmpty)
          HttpHeaders.authorizationHeader: 'Bearer $_apiKey',
      },
    );

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        endpoint,
        data: payload,
        options: options,
      );

      final data = response.data;
      if (data == null) {
        throw InterviewEvaluationException('평가 결과를 받지 못했습니다.');
      }

      final overallScore = (data['overallScore'] as num?)?.toDouble();
      if (overallScore == null) {
        throw InterviewEvaluationException('평가 점수가 포함되어 있지 않습니다.');
      }

      final feedbackList = data['feedback'] as List<dynamic>?;
      final perQuestionFeedback = feedbackList == null
          ? <QuestionFeedback>[]
          : feedbackList
              .whereType<Map<String, dynamic>>()
              .map(
                (item) => QuestionFeedback(
                  question: (item['question'] as String?)?.trim() ?? '',
                  feedback: (item['feedback'] as String?)?.trim() ?? '',
                  score: (item['score'] as num?)?.toDouble(),
                ),
              )
              .where((feedback) =>
                  feedback.question.isNotEmpty || feedback.feedback.isNotEmpty)
              .toList();

      return InterviewScore(
        overallScore: overallScore,
        perQuestionFeedback: perQuestionFeedback,
      );
    } on DioException catch (error) {
      final message = _mapDioErrorToMessage(error);
      throw InterviewEvaluationException(message, cause: error);
    } catch (error) {
      if (error is InterviewEvaluationException) rethrow;
      throw InterviewEvaluationException(
        '면접 평가 결과를 처리하는 중 오류가 발생했습니다.',
        cause: error,
      );
    }
  }

  String _mapDioErrorToMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return '평가 서버와 통신하지 못했습니다. 네트워크 상태를 확인해 주세요.';
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 401 || statusCode == 403) {
          return '평가 서비스 인증에 실패했습니다. 관리자에게 문의해 주세요.';
        }
        return '평가 요청이 실패했습니다. 잠시 후 다시 시도해 주세요.';
      case DioExceptionType.cancel:
        return '평가 요청이 취소되었습니다. 다시 시도해 주세요.';
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return '면접 평가 중 알 수 없는 오류가 발생했습니다.';
    }
  }
}

class InterviewEvaluationException implements Exception {
  InterviewEvaluationException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() {
    if (cause == null) {
      return 'InterviewEvaluationException: $message';
    }
    return 'InterviewEvaluationException: $message (cause: $cause)';
  }
}
