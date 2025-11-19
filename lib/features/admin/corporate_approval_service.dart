/// 기업 회원 미승인 신청을 모아보고 승인 상태를 업데이트하는 서비스.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

class CorporateApplicant {
  const CorporateApplicant({
    required this.uid,
    required this.email,
    required this.name,
    required this.companyName,
    required this.businessNumber,
    required this.source,
    required this.signupDocId,
    this.createdAt,
  });

  factory CorporateApplicant.fromSignupDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CorporateApplicant(
      uid: (data['uid'] ?? '') as String,
      email: (data['email'] ?? '') as String,
      name: (data['name'] ?? '') as String,
      companyName: (data['companyName'] ?? '') as String,
      businessNumber: (data['businessNumber'] ?? '') as String,
      createdAt: data['createdAt'] as Timestamp?,
      source: CorporateApplicantSource.corporateSignups,
      signupDocId: doc.id,
    );
  }

  factory CorporateApplicant.fromUserDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CorporateApplicant(
      uid: doc.id,
      email: (data['email'] ?? '') as String,
      name: (data['name'] ?? '') as String,
      companyName: (data['companyName'] ?? '') as String,
      businessNumber: (data['businessNumber'] ?? '') as String,
      createdAt: data['createdAt'] as Timestamp?,
      source: CorporateApplicantSource.users,
      signupDocId: null,
    );
  }

  final String uid;
  final String email;
  final String name;
  final String companyName;
  final String businessNumber;
  final CorporateApplicantSource source;
  final String? signupDocId;
  final Timestamp? createdAt;
}

enum CorporateApplicantSource { corporateSignups, users }

class CorporateApprovalService {
  CorporateApprovalService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<CorporateApplicant>> watchPendingApplicants() {
    final signupQuery = _firestore
        .collection('corporate_signups')
        .orderBy('createdAt', descending: true)
        .snapshots();
    final userQuery = _firestore
        .collection('users')
        .where('role', whereIn: ['corporate', 'company'])
        .where('isApproved', isEqualTo: false)
        .snapshots();

    return Stream.multi((controller) {
      var signupApplicants = <CorporateApplicant>[];
      var userApplicants = <CorporateApplicant>[];
      StreamSubscription? signupSub;
      StreamSubscription? userSub;

      void emitCombined() {
        final combined = <CorporateApplicant>[
          ...signupApplicants,
          ...userApplicants,
        ]..sort((a, b) {
            final aTime = a.createdAt?.toDate();
            final bTime = b.createdAt?.toDate();
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });
        controller.add(combined);
      }

      signupSub = signupQuery.listen(
        (snapshot) {
          signupApplicants = snapshot.docs
              .map((doc) {
                final data = doc.data();
                final processed = data?['processed'] == true;
                final alreadyApproved = data?['approved'] == true;
                if (processed || alreadyApproved) {
                  return null;
                }
                final applicant = CorporateApplicant.fromSignupDoc(doc);
                return applicant.uid.isEmpty ? null : applicant;
              })
              .whereType<CorporateApplicant>()
              .toList(growable: false);
          emitCombined();
        },
        onError: controller.addError,
      );

      userSub = userQuery.listen(
        (snapshot) {
          userApplicants = snapshot.docs
              .map(CorporateApplicant.fromUserDoc)
              .toList(growable: false);
          emitCombined();
        },
        onError: controller.addError,
      );

      controller.onCancel = () async {
        await signupSub?.cancel();
        await userSub?.cancel();
      };
    });
  }

  Future<void> setApproval({
    required CorporateApplicant applicant,
    required bool approved,
  }) async {
    if (applicant.uid.isEmpty) {
      throw StateError('사용자 UID가 필요합니다.');
    }

    final userRef = _firestore.collection('users').doc(applicant.uid);
    final signupRef = applicant.signupDocId == null
        ? null
        : _firestore.collection('corporate_signups').doc(applicant.signupDocId);

    await _firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      if (!userSnapshot.exists) {
        throw StateError('사용자 문서를 찾을 수 없습니다.');
      }

      transaction.update(userRef, {
        'isApproved': approved,
        'approvalUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (signupRef != null) {
        transaction.set(
            signupRef,
            {
              'processed': true,
              'approved': approved,
              'processedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      }
    });
  }
}
