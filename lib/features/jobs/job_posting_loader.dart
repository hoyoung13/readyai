import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'job_posting.dart';

/// 로컬 JSON 자산에서 채용공고를 불러오는 도우미.
class JobPostingLoader {
  const JobPostingLoader({this.assetPath = 'scripts/results.json'});

  final String assetPath;

  /// JSON 파일을 읽고 [JobFeed]로 변환한다.
  Future<JobFeed> load() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final dynamic decoded = jsonDecode(raw);
      if (decoded is List) {
        final items = <JobPosting>[];

        for (final entry in decoded) {
          final converted = _convertGovEntry(entry);
          if (converted != null) {
            items.add(converted);
            continue;
          }

          if (entry is Map<String, dynamic>) {
            try {
              items.add(JobPosting.fromJson(entry));
            } catch (_) {
              // 인식할 수 없는 항목은 건너뜀.
            }
          }
        }

        if (items.isNotEmpty) {
          return JobFeed(items: items);
        }
      }
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

JobPosting? _convertGovEntry(dynamic entry) {
  if (entry is! Map<String, dynamic>) {
    return null;
  }

  final listItem = entry['listItem'];
  if (listItem is! Map<String, dynamic>) {
    return null;
  }

  final payload = <String, dynamic>{};

  void putIfNotEmpty(String key, dynamic value) {
    if (value == null) {
      return;
    }
    if (value is String && value.trim().isEmpty) {
      return;
    }
    if (value is Iterable && value.isEmpty) {
      return;
    }
    payload[key] = value;
  }

  final title = _cleanText(listItem['recrutPbancTtl']);
  final company = _cleanText(listItem['instNm']);
  final region = _cleanText(listItem['workRgnNmLst']);
  final url = _cleanText(listItem['srcUrl']);
  final closingDate = _cleanText(listItem['pbancEndYmd']);

  if (title.isEmpty && company.isEmpty) {
    return null;
  }

  putIfNotEmpty('title', title);
  putIfNotEmpty('company', company);
  putIfNotEmpty('region', region);
  putIfNotEmpty('url', url);
  if (closingDate.isNotEmpty) {
    putIfNotEmpty('pbancEndYmd', closingDate);
  }

  final summaryItems = _buildSummaryItems(listItem);
  if (summaryItems.isNotEmpty) {
    putIfNotEmpty('summaryItems', summaryItems);
  }

  final detailRows = _buildDetailRows(listItem);
  if (detailRows.isNotEmpty) {
    putIfNotEmpty('detailRows', detailRows);
  }

  final description = _cleanMultiline(listItem['prefCondCn']);
  if (description.isNotEmpty) {
    putIfNotEmpty('description', description);
  }

  final notice = _buildNotice(listItem);
  if (notice.isNotEmpty) {
    putIfNotEmpty('notice', notice);
  }

  final tags = _buildTags(listItem);
  if (tags.isNotEmpty) {
    putIfNotEmpty('tags', tags);
  }

  return JobPosting.fromJson(payload);
}

List<Map<String, String>> _buildSummaryItems(Map<String, dynamic> raw) {
  final items = <Map<String, String>>[];

  void add(String label, dynamic value) {
    final text = _cleanText(value);
    if (text.isEmpty) {
      return;
    }
    items.add({'label': label, 'value': text});
  }

  add('모집구분', raw['recrutSeNm']);
  add('고용형태', raw['hireTypeNmLst']);
  add('근무지역', raw['workRgnNmLst']);

  final period = _formatDateRange(raw['pbancBgngYmd'], raw['pbancEndYmd']);
  if (period.isNotEmpty) {
    add('접수기간', period);
  }

  final recruitCount = _formatRecruitCount(raw['recrutNope']);
  if (recruitCount.isNotEmpty) {
    add('모집인원', recruitCount);
  }

  add('학력', raw['acbgCondNmLst']);
  return items;
}

List<Map<String, String>> _buildDetailRows(Map<String, dynamic> raw) {
  final rows = <Map<String, String>>[];

  void add(String title, dynamic value) {
    final text = _cleanMultiline(value);
    if (text.isEmpty) {
      return;
    }
    rows.add({'title': title, 'description': text});
  }

  add('지원 자격', raw['aplyQlfcCn']);
  add('우대 사항', raw['prefCondCn']);
  add('전형 절차', raw['scrnprcdrMthdExpln']);
  add('결격 사유', raw['disqlfcRsn']);

  return rows;
}

String _buildNotice(Map<String, dynamic> raw) {
  final notice = _cleanMultiline(raw['prefCn']);
  if (notice.isEmpty) {
    return '';
  }

  final normalized = notice.replaceAll(' ', '');
  const ignored = {
    '없음',
    '해당없음',
    '해당사항없음',
    '해당사항없습니다',
  };

  if (ignored.contains(normalized)) {
    return '';
  }
  return notice;
}

List<String> _buildTags(Map<String, dynamic> raw) {
  final tags = <String>{};

  void add(dynamic value) {
    final text = _cleanText(value);
    if (text.isNotEmpty) {
      tags.add(text);
    }
  }

  add(raw['recrutSeNm']);
  add(raw['hireTypeNmLst']);
  add(raw['acbgCondNmLst']);

  final decimalDay = _cleanText(raw['decimalDay']);
  if (decimalDay.isNotEmpty) {
    final number = int.tryParse(decimalDay);
    if (number != null) {
      tags.add(number <= 0 ? '마감임박' : 'D-$number');
    }
  }

  return tags.toList(growable: false);
}

String _cleanText(dynamic value) {
  if (value == null) {
    return '';
  }
  final text = value.toString().trim();
  if (text == 'null') {
    return '';
  }
  return text;
}

String _cleanMultiline(dynamic value) {
  final raw = _cleanText(value);
  if (raw.isEmpty) {
    return '';
  }

  final normalized = raw.replaceAll(RegExp(r'\r\n?|\n'), '\n');

  final lines = normalized
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);

  return lines.join('\n');
}

String _formatRecruitCount(dynamic value) {
  if (value == null) {
    return '';
  }

  if (value is num) {
    if (value <= 0) {
      return '';
    }
    return '${value.toInt()}명';
  }

  final text = _cleanText(value);
  final parsed = int.tryParse(text);
  if (parsed != null) {
    if (parsed <= 0) {
      return '';
    }
    return '${parsed}명';
  }

  return text;
}

String _formatDateRange(dynamic start, dynamic end) {
  final startText = _formatDate(start);
  final endText = _formatDate(end);

  if (startText.isEmpty && endText.isEmpty) {
    return '';
  }
  if (startText.isEmpty) {
    return endText;
  }
  if (endText.isEmpty) {
    return startText;
  }
  return '$startText ~ $endText';
}

String _formatDate(dynamic value) {
  final text = _cleanText(value);
  if (text.isEmpty) {
    return '';
  }

  if (RegExp(r'^\d{8}$').hasMatch(text)) {
    final year = text.substring(0, 4);
    final month = text.substring(4, 6);
    final day = text.substring(6, 8);
    return '$year.$month.$day';
  }

  return text;
}
