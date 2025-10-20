class JobFeed {
  const JobFeed({required this.items});

  final List<JobPosting> items;
  int get totalCount => items.length;

  factory JobFeed.fromJson(dynamic json) {
    final List<dynamic> rawList;
    if (json is List<dynamic>) {
      rawList = json;
    } else if (json is Map<String, dynamic>) {
      final dynamic jobs = json['jobs'];
      if (jobs is List<dynamic>) {
        rawList = jobs;
      } else {
        throw const FormatException('"jobs" 키에 리스트가 필요합니다.');
      }
    } else {
      throw const FormatException('지원하지 않는 JSON 형식입니다.');
    }

    final items = rawList
        .whereType<Map<String, dynamic>>()
        .map(JobPosting.fromJson)
        .toList(growable: false);

    return JobFeed(items: items);
  }
}

class JobPosting {
  const JobPosting({
    required this.title,
    required this.company,
    required this.region,
    required this.url,
    required this.postedDateText,
    this.postedDate,
  });

  final String title;
  final String company;
  final String region;
  final String url;
  final String postedDateText;
  final DateTime? postedDate;

  factory JobPosting.fromJson(Map<String, dynamic> json) {
    final title = _readFirst(json, const ['title', 'job_title', 'subject']);
    final company =
        _readFirst(json, const ['company', 'company_name', 'companyName']);
    final region = _readFirst(json, const ['region', 'location', 'area']);
    final url = _readFirst(json, const ['url', 'link', 'detail_url']);
    final postedDateText = _readFirst(
        json, const ['date', 'posted_date', 'postedDate', 'reg_date']);

    return JobPosting(
      title: title,
      company: company,
      region: region,
      url: url,
      postedDateText: postedDateText,
      postedDate: _parseDate(postedDateText),
    );
  }
  String get companyLabel => company.isNotEmpty ? company : '기업명 미확인';

  String get regionLabel => region.isNotEmpty ? region : '지역 정보 없음';

  /// UI 노출용 날짜 문자열. 원본 문자열이 없으면 null 반환.
  String? get prettyPostedDate {
    if (postedDate != null) {
      final month = postedDate!.month.toString().padLeft(2, '0');
      final day = postedDate!.day.toString().padLeft(2, '0');
      return '${postedDate!.year}.$month.$day';
    }

    final trimmed = postedDateText.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool get hasUrl => url.trim().isNotEmpty;
}

String _readFirst(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) {
      continue;
    }

    final text = value.toString().trim();
    if (text.isNotEmpty) {
      return text;
    }
  }
  return '';
}

DateTime? _parseDate(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final sanitized =
      trimmed.replaceAll(RegExp(r'[^0-9./-]'), '').replaceAll('..', '.');
  final candidates = <String>{
    sanitized,
    sanitized.replaceAll('.', '-'),
    sanitized.replaceAll('/', '-'),
  };

  for (final candidate in candidates) {
    final normalized = candidate;
    if (RegExp(r'^\d{8}$').hasMatch(normalized)) {
      final year = int.parse(normalized.substring(0, 4));
      final month = int.parse(normalized.substring(4, 6));
      final day = int.parse(normalized.substring(6, 8));
      return DateTime(year, month, day);
    }

    if (RegExp(r'^\d{4}-\d{1,2}-\d{1,2}$').hasMatch(normalized)) {
      final parts = normalized.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      return DateTime(year, month, day);
    }
  }
  return null;
}
