import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'job_posting.dart';

class JobPostingService {
  JobPostingService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<String> create(JobPostDraft draft) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const JobPostingServiceAuthException();
    }

    final ownerUid = draft.ownerUid.isNotEmpty ? draft.ownerUid : user.uid;

    final now = Timestamp.now();
    final doc = _firestore.collection('jobPosts').doc();
    await doc.set({
      ...draft.toFirestore(ownerUid: ownerUid),
      'createdAt': now,
      'updatedAt': now,
    });
    return doc.id;
  }

  Future<void> update(String id, JobPostDraft draft) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const JobPostingServiceAuthException();
    }

    final ownerUid = draft.ownerUid.isNotEmpty ? draft.ownerUid : user.uid;
    final doc = _firestore.collection('jobPosts').doc(id);
    await doc.update({
      ...draft.toFirestore(ownerUid: ownerUid),
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> delete(String id) =>
      _firestore.collection('jobPosts').doc(id).delete();

  Stream<List<JobPostRecord>> streamOwnerPosts(String ownerUid) {
    return _firestore
        .collection('jobPosts')
        .where('ownerUid', isEqualTo: ownerUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(JobPostRecord.fromDoc)
            .whereType<JobPostRecord>()
            .toList(growable: false));
  }

  Future<List<JobPostRecord>> fetchPublicPosts() async {
    final snapshot = await _firestore
        .collection('jobPosts')
        .where('isPublished', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map(JobPostRecord.fromDoc)
        .whereType<JobPostRecord>()
        .toList(growable: false);
  }

  Stream<List<JobApplicationRecord>> streamApplicationsForOwner(
    String ownerUid, {
    String? status,
    String? jobPostId,
  }) {
    Query<Map<String, dynamic>> query =
        _firestore.collectionGroup('applications').where(
              'ownerUid',
              isEqualTo: ownerUid,
            );

    if (status != null && status.isNotEmpty) {
      query = query.where('status', isEqualTo: status);
    }
    if (jobPostId != null && jobPostId.isNotEmpty) {
      query = query.where('jobPostId', isEqualTo: jobPostId);
    }

    return query.orderBy('appliedAt', descending: true).snapshots().map(
        (snapshot) => snapshot.docs
            .map(JobApplicationRecord.fromDoc)
            .whereType<JobApplicationRecord>()
            .toList(growable: false));
  }

  Stream<int> watchApplicationCount(String jobPostId) {
    return _firestore
        .collection('jobPosts')
        .doc(jobPostId)
        .collection('applications')
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Future<void> updateApplicationStatus(
    String jobPostId,
    String applicationId,
    String status,
  ) async {
    await _firestore
        .collection('jobPosts')
        .doc(jobPostId)
        .collection('applications')
        .doc(applicationId)
        .update({
      'status': status,
      'statusUpdatedAt': Timestamp.now(),
    });
  }
}

class JobPostDraft {
  const JobPostDraft({
    required this.ownerUid,
    required this.company,
    required this.title,
    required this.region,
    required this.recruitUrl,
    required this.applicationStartDate,
    required this.applicationEndDate,
    this.tags = const <String>[],
    this.occupations = const <String>[],
    this.description = '',
    this.notice = '',
    this.isPublished = true,
  });

  final String ownerUid;
  final String company;
  final String title;
  final String region;
  final String recruitUrl;
  final DateTime applicationStartDate;
  final DateTime applicationEndDate;
  final List<String> tags;
  final List<String> occupations;
  final String description;
  final String notice;
  final bool isPublished;

  Map<String, dynamic> toFirestore({required String ownerUid}) {
    return {
      'ownerUid': ownerUid,
      'company': company,
      'title': title,
      'region': region,
      'url': recruitUrl,
      'applicationStartDate': Timestamp.fromDate(applicationStartDate),
      'applicationEndDate': Timestamp.fromDate(applicationEndDate),
      'tags': tags,
      'occupations': occupations,
      'description': description,
      'notice': notice,
      'isPublished': isPublished,
    };
  }
}

class JobPostRecord {
  const JobPostRecord({
    required this.id,
    required this.ownerUid,
    required this.company,
    required this.title,
    required this.region,
    required this.url,
    required this.applicationStartDate,
    required this.applicationEndDate,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const <String>[],
    this.occupations = const <String>[],
    this.description = '',
    this.notice = '',
    this.isPublished = true,
  });

  final String id;
  final String ownerUid;
  final String company;
  final String title;
  final String region;
  final String url;
  final DateTime applicationStartDate;
  final DateTime applicationEndDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final List<String> occupations;
  final String description;
  final String notice;
  final bool isPublished;

  static JobPostRecord? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      return null;
    }

    try {
      final applicationStart =
          (data['applicationStartDate'] as Timestamp?)?.toDate();
      final applicationEnd =
          (data['applicationEndDate'] as Timestamp?)?.toDate();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();

      if (applicationStart == null || applicationEnd == null) {
        return null;
      }

      return JobPostRecord(
        id: doc.id,
        ownerUid: (data['ownerUid'] ?? '').toString(),
        company: (data['company'] ?? '').toString(),
        title: (data['title'] ?? '').toString(),
        region: (data['region'] ?? '').toString(),
        url: (data['url'] ?? '').toString(),
        applicationStartDate: applicationStart,
        applicationEndDate: applicationEnd,
        createdAt: createdAt ?? DateTime.now(),
        updatedAt: updatedAt ?? DateTime.now(),
        tags: _normalizeList(data['tags']),
        occupations: _normalizeList(data['occupations']),
        description: (data['description'] ?? '').toString(),
        notice: (data['notice'] ?? '').toString(),
        isPublished: data['isPublished'] != false,
      );
    } catch (_) {
      return null;
    }
  }

  JobPosting toJobPosting() {
    return JobPosting(
      title: title,
      company: company,
      region: region,
      url: url,
      postedDateText: _formatDate(createdAt),
      postedDate: createdAt,
      applicationStartDateText: _formatDate(applicationStartDate),
      applicationStartDate: applicationStartDate,
      applicationEndDateText: _formatDate(applicationEndDate),
      applicationEndDate: applicationEndDate,
      tags: tags,
      occupations: occupations,
      description: description,
      notice: notice,
      summaryItems: [
        JobSummaryItem(
            label: '접수 시작', value: _formatDate(applicationStartDate)),
        JobSummaryItem(label: '접수 마감', value: _formatDate(applicationEndDate)),
      ],
    );
  }
}

class JobApplicationRecord {
  const JobApplicationRecord({
    required this.id,
    required this.jobPostId,
    required this.ownerUid,
    required this.applicantUid,
    required this.applicantName,
    required this.status,
    required this.appliedAt,
    this.resumeUrl,
    this.memo,
  });

  final String id;
  final String jobPostId;
  final String ownerUid;
  final String applicantUid;
  final String applicantName;
  final String status;
  final DateTime appliedAt;
  final String? resumeUrl;
  final String? memo;

  static JobApplicationRecord? fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final appliedAt = (data['appliedAt'] as Timestamp?)?.toDate();
    if (appliedAt == null) {
      return null;
    }

    return JobApplicationRecord(
      id: doc.id,
      jobPostId: (data['jobPostId'] ?? '').toString(),
      ownerUid: (data['ownerUid'] ?? '').toString(),
      applicantUid: (data['applicantUid'] ?? '').toString(),
      applicantName: (data['applicantName'] ?? '').toString(),
      status: (data['status'] ?? JobApplicationStatus.submitted).toString(),
      appliedAt: appliedAt,
      resumeUrl: (data['resumeUrl'] as String?),
      memo: (data['memo'] as String?),
    );
  }
}

class JobApplicationStatus {
  static const submitted = 'submitted';
  static const reviewing = 'reviewing';
  static const accepted = 'accepted';
  static const rejected = 'rejected';

  static const labels = {
    submitted: '지원 접수',
    reviewing: '검토 중',
    accepted: '합격',
    rejected: '불합격',
  };
}

class JobPostingServiceAuthException implements Exception {
  const JobPostingServiceAuthException();
}

List<String> _normalizeList(dynamic value) {
  if (value == null) {
    return const <String>[];
  }
  if (value is Iterable) {
    return value
        .map((e) => (e ?? '').toString().trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }
  final text = value.toString().trim();
  if (text.isEmpty) {
    return const <String>[];
  }
  return text
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

String _formatDate(DateTime date) {
  return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}
