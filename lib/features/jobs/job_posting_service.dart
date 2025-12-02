import 'dart:async';
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

    final ownerUid = draft.authorId.isNotEmpty ? draft.authorId : user.uid;

    final doc = _firestore.collection('jobPosts').doc();
    await doc.set({
      ...draft.toFirestore(authorId: ownerUid),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> update(String id, JobPostDraft draft) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const JobPostingServiceAuthException();
    }

    final ownerUid = draft.authorId.isNotEmpty ? draft.authorId : user.uid;
    final doc = _firestore.collection('jobPosts').doc(id);
    await doc.update({
      ...draft.toFirestore(authorId: ownerUid),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String id) =>
      _firestore.collection('jobPosts').doc(id).delete();

  Stream<List<JobPostRecord>> streamOwnerPosts(String ownerUid) {
    final controller = StreamController<List<JobPostRecord>>();
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? authorSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? ownerSub;

    var authorPosts = const <JobPostRecord>[];
    var ownerPosts = const <JobPostRecord>[];

    List<JobPostRecord> _mergeAndSort() {
      final merged = <String, JobPostRecord>{};
      for (final post in [...authorPosts, ...ownerPosts]) {
        merged[post.id] = post;
      }
      final list = merged.values.toList(growable: false);
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }

    void attachAuthorListener() {
      authorSub?.cancel();
      authorSub = _firestore
          .collection('jobPosts')
          .where('authorId', isEqualTo: ownerUid)
          .snapshots()
          .listen((snapshot) {
        authorPosts = snapshot.docs
            .map(JobPostRecord.fromDoc)
            .whereType<JobPostRecord>()
            .toList(growable: false);
        controller.add(_mergeAndSort());
      }, onError: controller.addError);
    }

    void attachOwnerListener() {
      ownerSub?.cancel();
      ownerSub = _firestore
          .collection('jobPosts')
          .where('ownerUid', isEqualTo: ownerUid)
          .snapshots()
          .listen((snapshot) {
        ownerPosts = snapshot.docs
            .map(JobPostRecord.fromDoc)
            .whereType<JobPostRecord>()
            .toList(growable: false);
        controller.add(_mergeAndSort());
      }, onError: controller.addError);
    }

    attachAuthorListener();
    attachOwnerListener();

    controller.onCancel = () {
      authorSub?.cancel();
      ownerSub?.cancel();
    };

    return controller.stream;
  }

  Stream<List<JobPostRecord>> streamAllPosts({int limit = 50}) {
    return _firestore
        .collection('jobPosts')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(JobPostRecord.fromDoc)
            .whereType<JobPostRecord>()
            .toList(growable: false));
  }

  Future<List<JobPostRecord>> fetchPublicPosts() async {
    final snapshot = await _firestore
        .collection('jobPosts')
        .where('isApproved', isEqualTo: true)
        .where('isActive', isEqualTo: true)
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

  Future<JobApplicationRecord> submitApplication({
    required String jobPostId,
    required String ownerUid,
    required String jobTitle,
    required String jobCompany,
    required String applicantUid,
    required String applicantName,
    String? resumeUrl,
    String? resumeFileName,
    String? coverLetterUrl,
    String? coverLetterFileName,
    String? memo,
    String? interviewVideoUrl,
    String? interviewSummary,
  }) async {
    final trimmedName = applicantName.trim();
    if (trimmedName.isEmpty) {
      throw const JobPostingServiceAuthException();
    }

    final now = Timestamp.now();
    final data = <String, Object?>{
      'jobPostId': jobPostId,
      'ownerUid': ownerUid,
      'jobTitle': jobTitle,
      'jobCompany': jobCompany,
      'applicantUid': applicantUid,
      'applicantName': trimmedName,
      'status': JobApplicationStatus.submitted,
      'appliedAt': now,
      'resumeUrl': resumeUrl?.trim(),
      'resumeFileName': resumeFileName?.trim(),
      'coverLetterUrl': coverLetterUrl?.trim(),
      'coverLetterFileName': coverLetterFileName?.trim(),
      'memo': memo?.trim(),
      'interviewVideoUrl': interviewVideoUrl?.trim(),
      'interviewSummary': interviewSummary?.trim(),
    }..removeWhere((key, value) =>
        value == null || (value is String && value.trim().isEmpty));

    final doc = _firestore
        .collection('jobPosts')
        .doc(jobPostId)
        .collection('applications')
        .doc();

    await doc.set(data);
    await _firestore.collection('jobPosts').doc(jobPostId).update({
      'applicantCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return JobApplicationRecord(
      id: doc.id,
      jobPostId: jobPostId,
      ownerUid: ownerUid,
      applicantUid: applicantUid,
      applicantName: trimmedName,
      status: JobApplicationStatus.submitted,
      appliedAt: now.toDate(),
      resumeUrl: resumeUrl?.trim(),
      resumeFileName: resumeFileName?.trim(),
      coverLetterUrl: coverLetterUrl?.trim(),
      coverLetterFileName: coverLetterFileName?.trim(),
      memo: memo?.trim(),
      interviewVideoUrl: interviewVideoUrl?.trim(),
      interviewSummary: interviewSummary?.trim(),
      jobTitle: jobTitle,
      jobCompany: jobCompany,
    );
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

  Future<void> setVisibility({
    required String jobPostId,
    required bool visible,
    String blockedReason = '',
  }) async {
    await _firestore.collection('jobPosts').doc(jobPostId).update({
      'isApproved': visible,
      'isActive': visible,
      'blockedReason': blockedReason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setApproval({
    required String jobPostId,
    required bool approved,
    String blockedReason = '',
  }) async {
    await _firestore.collection('jobPosts').doc(jobPostId).update({
      'isApproved': approved,
      'isActive': approved,
      'blockedReason': approved ? '' : blockedReason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

class JobPostDraft {
  const JobPostDraft({
    required this.title,
    required this.category,
    required this.subCategory,
    required this.employmentType,
    required this.experienceLevel,
    required this.education,
    required this.description,
    required this.qualification,
    required this.preferred,
    required this.process,
    required this.location,
    required this.workHours,
    required this.salary,
    required this.benefits,
    required this.companyName,
    required this.contactName,
    required this.contactEmail,
    required this.contactPhone,
    required this.applyMethod,
    required this.additionalNotes,
    required this.deadline,
    required this.authorId,
    this.interviewQuestions = const <String>[],
    this.companyWebsite,
    this.attachments = const <String>[],
    this.startDate,
    this.isApproved = false,
    this.isActive = true,
    this.viewCount = 0,
    this.applicantCount = 0,
    this.blockReason = '',
  });

  final String title;
  final String category;
  final String subCategory;
  final String employmentType;
  final String experienceLevel;
  final String education;
  final String description;
  final String qualification;
  final String preferred;
  final String process;
  final String location;
  final String workHours;
  final String salary;
  final String benefits;
  final String companyName;
  final String? companyWebsite;
  final String contactName;
  final String contactEmail;
  final String contactPhone;
  final String applyMethod;
  final List<String> attachments;
  final String additionalNotes;
  final List<String> interviewQuestions;
  final DateTime? startDate;
  final DateTime deadline;
  final String authorId;
  final bool isApproved;
  final bool isActive;
  final int viewCount;
  final int applicantCount;
  final String blockReason;

  Map<String, dynamic> toFirestore({required String authorId}) {
    final active = deadline.isAfter(DateTime.now());
    return {
      'title': title,
      'category': category,
      'subCategory': subCategory,
      'employmentType': employmentType,
      'experienceLevel': experienceLevel,
      'education': education,
      'description': description,
      'qualification': qualification,
      'preferred': preferred,
      'process': process,
      'location': location,
      'workHours': workHours,
      'salary': salary,
      'benefits': benefits,
      'companyName': companyName,
      'companyWebsite': companyWebsite,
      'contactName': contactName,
      'contactEmail': contactEmail,
      'contactPhone': contactPhone,
      'applyMethod': applyMethod,
      'attachments': attachments,
      'additionalNotes': additionalNotes,
      'interviewQuestions': interviewQuestions,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'deadline': Timestamp.fromDate(deadline),
      'authorId': authorId,
      'ownerUid': authorId,
      'isApproved': isApproved,
      'isActive': isActive && active,
      'viewCount': viewCount,
      'applicantCount': applicantCount,
      'blockedReason': blockReason,
    }..removeWhere((key, value) => value == null);
  }
}

class JobPostRecord {
  const JobPostRecord({
    required this.id,
    required this.authorId,
    required this.companyName,
    required this.title,
    required this.category,
    required this.subCategory,
    required this.employmentType,
    required this.experienceLevel,
    required this.education,
    required this.description,
    required this.qualification,
    required this.preferred,
    required this.process,
    required this.location,
    required this.workHours,
    required this.salary,
    required this.benefits,
    required this.contactName,
    required this.contactEmail,
    required this.contactPhone,
    required this.applyMethod,
    required this.attachments,
    required this.additionalNotes,
    required this.interviewQuestions,
    required this.deadline,
    required this.createdAt,
    required this.updatedAt,
    required this.isApproved,
    required this.isActive,
    required this.viewCount,
    required this.applicantCount,
    this.companyWebsite,
    this.startDate,
    this.blockReason = '',
  });

  final String id;
  final String authorId;
  final String companyName;
  final String title;
  final String category;
  final String subCategory;
  final String employmentType;
  final String experienceLevel;
  final String education;
  final String description;
  final String qualification;
  final String preferred;
  final String process;
  final String location;
  final String workHours;
  final String salary;
  final String benefits;
  final String contactName;
  final String contactEmail;
  final String contactPhone;
  final String applyMethod;
  final List<String> attachments;
  final String additionalNotes;
  final List<String> interviewQuestions;
  final DateTime? startDate;
  final DateTime deadline;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isApproved;
  final bool isActive;
  final int viewCount;
  final int applicantCount;
  final String? companyWebsite;
  final String blockReason;

  String get company => companyName;
  String get region => location;
  DateTime get applicationStartDate => startDate ?? createdAt;
  DateTime get applicationEndDate => deadline;
  String get url => applyMethod;
  List<String> get tags => attachments;
  List<String> get occupations => const [];
  String get notice => additionalNotes;
  bool get visible => isApproved && isActive;
  String get blockedReason =>
      blockReason.isNotEmpty ? blockReason : (isApproved ? '' : '관리자 검토 전 비공개');

  static JobPostRecord? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      return null;
    }

    try {
      final createdAt =
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
      final startDate = (data['startDate'] as Timestamp?)?.toDate();
      final deadline = (data['deadline'] as Timestamp?)?.toDate();

      if (deadline == null) {
        return null;
      }

      return JobPostRecord(
        id: doc.id,
        authorId: (data['authorId'] ?? data['ownerUid'] ?? '').toString(),
        companyName: (data['companyName'] ?? data['company'] ?? '').toString(),
        title: (data['title'] ?? '').toString(),
        category: (data['category'] ?? '').toString(),
        subCategory: (data['subCategory'] ?? '').toString(),
        employmentType: (data['employmentType'] ?? '').toString(),
        experienceLevel: (data['experienceLevel'] ?? '').toString(),
        education: (data['education'] ?? '').toString(),
        description: (data['description'] ?? '').toString(),
        qualification: (data['qualification'] ?? '').toString(),
        preferred: (data['preferred'] ?? '').toString(),
        process: (data['process'] ?? '').toString(),
        location: (data['location'] ?? data['region'] ?? '').toString(),
        workHours: (data['workHours'] ?? '').toString(),
        salary: (data['salary'] ?? '').toString(),
        benefits: (data['benefits'] ?? '').toString(),
        contactName: (data['contactName'] ?? '').toString(),
        contactEmail: (data['contactEmail'] ?? '').toString(),
        contactPhone: (data['contactPhone'] ?? '').toString(),
        applyMethod: (data['applyMethod'] ?? data['url'] ?? '').toString(),
        attachments: _normalizeList(data['attachments']),
        additionalNotes: (data['additionalNotes'] ?? '').toString(),
        interviewQuestions: _normalizeList(data['interviewQuestions']),
        startDate: startDate,
        deadline: deadline,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
        isApproved: data['isApproved'] == true,
        isActive: data['isActive'] != false,
        viewCount: int.tryParse('${data['viewCount'] ?? 0}') ?? 0,
        applicantCount: int.tryParse('${data['applicantCount'] ?? 0}') ?? 0,
        companyWebsite: (data['companyWebsite'] ?? '') as String?,
        blockReason: (data['blockedReason'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }

  JobPosting toJobPosting() {
    return JobPosting(
      title: title,
      company: companyName,
      region: location,
      url: applyMethod,
      postId: id,
      ownerUid: authorId,
      postedDateText: _formatDate(createdAt),
      postedDate: createdAt,
      applicationStartDateText: _formatDate(startDate ?? createdAt),
      applicationStartDate: startDate ?? createdAt,
      applicationEndDateText: _formatDate(deadline),
      applicationEndDate: deadline,
      tags: attachments,
      occupations: const [],
      description: description,
      notice: additionalNotes,
      visible: isApproved && isActive,
      blockedReason: blockedReason,
      interviewQuestions: interviewQuestions,
      summaryItems: [
        JobSummaryItem(
            label: '접수 시작', value: _formatDate(startDate ?? createdAt)),
        JobSummaryItem(label: '접수 마감', value: _formatDate(deadline)),
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
    this.resumeFileName,
    this.coverLetterUrl,
    this.coverLetterFileName,
    this.memo,
    this.interviewVideoUrl,
    this.interviewSummary,
    this.jobTitle = '',
    this.jobCompany = '',
  });

  final String id;
  final String jobPostId;
  final String ownerUid;
  final String applicantUid;
  final String applicantName;
  final String status;
  final DateTime appliedAt;
  final String? resumeUrl;
  final String? resumeFileName;
  final String? coverLetterUrl;
  final String? coverLetterFileName;
  final String? memo;
  final String? interviewVideoUrl;
  final String? interviewSummary;
  final String jobTitle;
  final String jobCompany;

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
      resumeFileName: (data['resumeFileName'] as String?),
      coverLetterUrl: (data['coverLetterUrl'] as String?),
      coverLetterFileName: (data['coverLetterFileName'] as String?),
      memo: (data['memo'] as String?),
      interviewVideoUrl: (data['interviewVideoUrl'] as String?),
      interviewSummary: (data['interviewSummary'] as String?),
      jobTitle: (data['jobTitle'] ?? '').toString(),
      jobCompany: (data['jobCompany'] ?? '').toString(),
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
