import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'job_posting.dart';

/// 로컬 JSON 자산에서 채용공고를 불러오는 도우미.
class JobPostingLoader {
  const JobPostingLoader({this.assetPath = 'assets/jobs.json'});

  /// 불러올 JSON 파일 경로. 기본값은 [assets/jobs.json].
  final String assetPath;

  /// JSON 파일을 읽고 [JobFeed]로 변환한다.
  Future<JobFeed> load() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final dynamic decoded = jsonDecode(raw);
      return JobFeed.fromJson(decoded);
    } on FormatException catch (error) {
      throw JobPostingLoadException('채용공고 데이터를 해석하지 못했습니다.', error);
    } catch (error) {
      throw JobPostingLoadException('채용공고 데이터를 불러오는 데 실패했습니다.', error);
    }
  }
}

/// 채용공고 로딩 중 발생하는 예외.
class JobPostingLoadException implements Exception {
  JobPostingLoadException(this.message, [this.inner]);

  final String message;
  final Object? inner;

  @override
  String toString() {
    if (inner == null) {
      return message;
    }
    return '$message (${inner.toString()})';
  }
}