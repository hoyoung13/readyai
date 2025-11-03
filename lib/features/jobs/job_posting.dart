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

class JobSummaryItem {
  const JobSummaryItem({required this.label, required this.value});

  final String label;
  final String value;

  factory JobSummaryItem.fromJson(Map<String, dynamic> json) {
    final label = (json['label'] ?? '').toString();
    final value = (json['value'] ?? '').toString();
    return JobSummaryItem(label: label, value: value);
  }

  bool get isEmpty => label.trim().isEmpty && value.trim().isEmpty;
}

class JobDetailRow {
  const JobDetailRow({required this.title, required this.description});

  final String title;
  final String description;

  factory JobDetailRow.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] ?? '').toString();
    final description = (json['description'] ?? '').toString();
    return JobDetailRow(title: title, description: description);
  }

  bool get isEmpty => title.trim().isEmpty && description.trim().isEmpty;
}

class JobPosting {
  const JobPosting({
    required this.title,
    required this.company,
    required this.region,
    required this.url,
    required this.postedDateText,
    this.postedDate,
    this.tags = const <String>[],
    this.summaryItems = const <JobSummaryItem>[],
    this.detailRows = const <JobDetailRow>[],
    this.description = '',
    this.notice = '',
  });

  final String title;
  final String company;
  final String region;
  final String url;
  final String postedDateText;
  final DateTime? postedDate;
  final List<String> tags;
  final List<JobSummaryItem> summaryItems;
  final List<JobDetailRow> detailRows;
  final String description;
  final String notice;

  factory JobPosting.fromJson(Map<String, dynamic> json) {
    final title = _readFirst(json, const [
      'title',
      'job_title',
      'subject',
      'recruitmentTitle',
      'busiNm',
      'announcementTitle',
      'jobTitle',
    ]);
    final company = _readFirst(json, const [
      'company',
      'company_name',
      'companyName',
      'instNm',
      'organNm',
      'orgName',
      'publicInstitutionNm',
      'agency',
      'organization',
    ]);
    final region = _readFirst(json, const [
      'region',
      'location',
      'area',
      'workPlcNm',
      'workRegion',
      'workRegionNm',
      'workLocation',
      'workPlace',
    ]);
    final url = _readFirst(json, const [
      'url',
      'link',
      'detail_url',
      'detailUrl',
      'detailLink',
      'infoUrl',
      'homepageUrl',
      'recruitUrl',
    ]);
    final postedDateText = _readFirst(json, const [
      'date',
      'posted_date',
      'postedDate',
      'reg_date',
      'receiptCloseDt',
      'receiptEndDt',
      'rcptEdDt',
      'deadline',
      'applyEndDate',
    ]);
    final tags = (json['tags'] as List<dynamic>?)
            ?.map((dynamic value) => value.toString().trim())
            .where((element) => element.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];

    final summaryItems = (json['summaryItems'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(JobSummaryItem.fromJson)
            .where((element) => !element.isEmpty)
            .toList(growable: false) ??
        const <JobSummaryItem>[];

    final detailRows = (json['detailRows'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(JobDetailRow.fromJson)
            .where((element) => !element.isEmpty)
            .toList(growable: false) ??
        const <JobDetailRow>[];

    final description = (json['description'] ?? '').toString();
    final notice = (json['notice'] ?? '').toString();

    return JobPosting(
      title: title,
      company: company,
      region: region,
      url: url,
      postedDateText: postedDateText,
      postedDate: _parseDate(postedDateText),
      tags: tags,
      summaryItems: summaryItems,
      detailRows: detailRows,
      description: description,
      notice: notice,
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

  String get tagsSummary {
    if (tags.isNotEmpty) {
      return tags.join(' · ');
    }

    final location = regionLabel;
    final date = prettyPostedDate;
    if (date != null) {
      return '$location · $date';
    }
    return location;
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
