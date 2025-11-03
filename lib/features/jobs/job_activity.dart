import 'package:cloud_firestore/cloud_firestore.dart';

class JobActivity {
  const JobActivity({
    required this.jobId,
    required this.title,
    required this.company,
    required this.region,
    required this.url,
    required this.scrapped,
    required this.applied,
    this.scrappedAt,
    this.appliedAt,
    this.applicationStartDate,
    this.applicationStartDateText,
    this.applicationEndDate,
    this.applicationEndDateText,
    this.postedDateText,
    this.updatedAt,
  });

  final String jobId;
  final String title;
  final String company;
  final String region;
  final String url;
  final bool scrapped;
  final bool applied;
  final DateTime? scrappedAt;
  final DateTime? appliedAt;
  final DateTime? applicationStartDate;
  final String? applicationStartDateText;
  final DateTime? applicationEndDate;
  final String? applicationEndDateText;
  final String? postedDateText;
  final DateTime? updatedAt;

  factory JobActivity.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return JobActivity(
      jobId: data['jobId'] as String? ?? doc.id,
      title: data['title'] as String? ?? '제목 없음',
      company: data['company'] as String? ?? '기업 정보 없음',
      region: data['region'] as String? ?? '지역 정보 없음',
      url: data['url'] as String? ?? '',
      scrapped: data['scrapped'] == true,
      applied: data['applied'] == true,
      scrappedAt: (data['scrappedAt'] as Timestamp?)?.toDate(),
      appliedAt: (data['appliedAt'] as Timestamp?)?.toDate(),
      applicationStartDate:
          (data['applicationStartDate'] as Timestamp?)?.toDate(),
      applicationStartDateText:
          (data['applicationStartDateText'] as String?)?.trim(),
      applicationEndDate: (data['applicationEndDate'] as Timestamp?)?.toDate(),
      applicationEndDateText:
          (data['applicationEndDateText'] as String?)?.trim(),
      postedDateText: (data['postedDateText'] as String?)?.trim(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  String? get registrationDateLabel {
    final date = applicationStartDate ?? scrappedAt;
    if (date != null) {
      return _formatDate(date);
    }
    final fallback = applicationStartDateText ?? postedDateText;
    if (fallback == null || fallback.isEmpty) {
      return null;
    }
    return fallback;
  }

  String? get applicationDeadlineLabel {
    if (applicationEndDate != null) {
      return _formatDate(applicationEndDate!);
    }
    final fallback = applicationEndDateText;
    if (fallback == null || fallback.isEmpty) {
      return null;
    }
    return fallback;
  }

  String? get appliedAtLabel {
    if (appliedAt == null) {
      return null;
    }
    return _formatDate(appliedAt!);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'jobId': jobId,
      'title': title,
      'company': company,
      'region': region,
      'url': url,
      'scrapped': scrapped,
      'applied': applied,
      if (scrappedAt != null) 'scrappedAt': Timestamp.fromDate(scrappedAt!),
      if (appliedAt != null) 'appliedAt': Timestamp.fromDate(appliedAt!),
      if (applicationStartDate != null)
        'applicationStartDate': Timestamp.fromDate(applicationStartDate!),
      if (applicationStartDateText != null)
        'applicationStartDateText': applicationStartDateText,
      if (applicationEndDate != null)
        'applicationEndDate': Timestamp.fromDate(applicationEndDate!),
      if (applicationEndDateText != null)
        'applicationEndDateText': applicationEndDateText,
      if (postedDateText != null) 'postedDateText': postedDateText,
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  static String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}.$month.$day';
  }
}