import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'job_posting.dart';

class JobPostingApi {
  JobPostingApi({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  static const _endpoint =
      'https://www.copyright.or.kr/notify/recruitment/openAPI.do';

  final http.Client _httpClient;

  Future<JobFeed> fetch(
      {required DateTime start, required DateTime end}) async {
    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'startdt': _formatDate(start),
      'enddt': _formatDate(end),
    });

    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw JobPostingRequestException('요청이 실패했습니다. (${response.statusCode})');
    }

    try {
      final document = XmlDocument.parse(utf8.decode(response.bodyBytes));
      return JobFeed.fromXml(document);
    } on XmlException catch (e) {
      throw JobPostingParseException('채용공고 데이터를 해석하지 못했습니다.', e);
    }
  }

  void dispose() {
    _httpClient.close();
  }
}

class JobPostingRequestException implements Exception {
  JobPostingRequestException(this.message);
  final String message;

  @override
  String toString() => 'JobPostingRequestException: $message';
}

class JobPostingParseException implements Exception {
  JobPostingParseException(this.message, [this.inner]);

  final String message;
  final Object? inner;

  @override
  String toString() => 'JobPostingParseException: $message';
}

String _formatDate(DateTime dateTime) {
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  return '${dateTime.year}$month$day';
}
