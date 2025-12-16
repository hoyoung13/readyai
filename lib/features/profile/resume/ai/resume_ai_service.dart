import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ai/features/profile/resume/ai/resume_ai_models.dart';
import 'package:ai/features/profile/resume/models/resume.dart';

class ResumeAiService {
  ResumeAiService({String? baseUrl})
      : _baseUrl = baseUrl ??
            const String.fromEnvironment('RESUME_AI_BASE_URL',
                defaultValue: 'http://172.16.104.3:8000');

  final String _baseUrl;

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<ProcessedDocumentResult> processDocument({
    required String fileUrl,
    required String fileType,
    required ResumeDocKind docKind,
    required String language,
    String? targetRole,
  }) async {
    final response = await http.post(
      _uri('/api/document/process'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fileUrl': fileUrl,
        'fileType': fileType,
        'docKind': docKind.name,
        'language': language,
        'targetRole': targetRole,
      }),
    );
    _throwIfError(response);
    return ProcessedDocumentResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<EvaluationResponse> evaluate({
    required String extractedText,
    required ResumeDocKind docKind,
    required String language,
    String? targetRole,
  }) async {
    final response = await http.post(
      _uri('/api/ai/evaluate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'extractedText': extractedText,
        'docKind': docKind.name,
        'language': language,
        'targetRole': targetRole,
      }),
    );
    _throwIfError(response);
    return EvaluationResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<SummaryResult> summarize({
    required String extractedText,
    required String language,
  }) async {
    final response = await http.post(
      _uri('/api/ai/summarize'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'extractedText': extractedText,
        'language': language,
      }),
    );
    _throwIfError(response);
    return SummaryResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<ProofreadResult> proofread({
    required String extractedText,
    required String language,
    String? targetRole,
  }) async {
    final response = await http.post(
      _uri('/api/ai/proofread'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'extractedText': extractedText,
        'language': language,
        'targetRole': targetRole,
      }),
    );
    _throwIfError(response);
    return ProofreadResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  void _throwIfError(http.Response response) {
    if (response.statusCode >= 400) {
      final message = _parseMessage(response.body);
      throw Exception(message);
    }
  }

  String _parseMessage(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return (json['detail'] ?? json['message'] ?? '요청에 실패했습니다').toString();
    } catch (_) {
      return '요청에 실패했습니다';
    }
  }
}
