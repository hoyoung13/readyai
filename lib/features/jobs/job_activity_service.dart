import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'job_activity.dart';
import 'job_posting.dart';

class JobActivityAuthException implements Exception {
  const JobActivityAuthException();
}

class JobActivityService {
  factory JobActivityService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) {
    return JobActivityService._(
      firestore ?? FirebaseFirestore.instance,
      auth ?? FirebaseAuth.instance,
    );
  }

  JobActivityService._(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  User? get _currentUser => _auth.currentUser;

  Stream<JobActivity?> watch(JobPosting job) {
    final doc = _activityDoc(job);
    if (doc == null) {
      return Stream<JobActivity?>.value(null);
    }
    return doc.snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      return JobActivity.fromDoc(snapshot);
    });
  }

  Stream<List<JobActivity>> watchAll() {
    final user = _currentUser;
    if (user == null) {
      return Stream<List<JobActivity>>.value(const []);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('jobActivities')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => JobActivity.fromDoc(doc))
            .toList(growable: false));
  }

  Future<bool> toggleScrap(JobPosting job) async {
    final doc = _activityDoc(job);
    if (doc == null) {
      throw const JobActivityAuthException();
    }

    return _firestore.runTransaction((transaction) async {
      final now = Timestamp.now();
      final snapshot = await transaction.get(doc);
      final metadata = _buildMetadata(job, now);

      if (!snapshot.exists) {
        transaction.set(doc, {
          ...metadata,
          'scrapped': true,
          'scrappedAt': now,
          'applied': false,
        });
        return true;
      }

      final current = snapshot.data() ?? const <String, dynamic>{};
      final currentScrapped = current['scrapped'] == true;
      final nextScrapped = !currentScrapped;
      final updates = <String, dynamic>{
        ...metadata,
        'scrapped': nextScrapped,
      };

      if (nextScrapped) {
        updates['scrappedAt'] = now;
      } else {
        updates['scrappedAt'] = FieldValue.delete();
      }

      transaction.update(doc, updates);
      return nextScrapped;
    });
  }

  Future<bool> recordApplication(JobPosting job) async {
    final doc = _activityDoc(job);
    if (doc == null) {
      throw const JobActivityAuthException();
    }

    return _firestore.runTransaction((transaction) async {
      final now = Timestamp.now();
      final snapshot = await transaction.get(doc);
      final metadata = _buildMetadata(job, now);

      if (!snapshot.exists) {
        transaction.set(doc, {
          ...metadata,
          'scrapped': false,
          'applied': true,
          'appliedAt': now,
        });
        return true;
      }

      final current = snapshot.data() ?? const <String, dynamic>{};
      final alreadyApplied = current['applied'] == true;
      final updates = <String, dynamic>{
        ...metadata,
        'applied': true,
        'appliedAt': now,
      };

      transaction.update(doc, updates);
      return !alreadyApplied;
    });
  }

  DocumentReference<Map<String, dynamic>>? _activityDoc(JobPosting job) {
    final user = _currentUser;
    if (user == null) {
      return null;
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('jobActivities')
        .doc(job.uniqueId);
  }

  Map<String, dynamic> _buildMetadata(JobPosting job, Timestamp now) {
    final data = <String, dynamic>{
      'jobId': job.uniqueId,
      'title': job.title,
      'company': job.companyLabel,
      'region': job.regionLabel,
      'url': job.url,
      'postedDateText': job.postedDateText,
      'updatedAt': now,
    };

    if (job.applicationStartDate != null) {
      data['applicationStartDate'] =
          Timestamp.fromDate(job.applicationStartDate!);
    }
    if (job.applicationStartDateText.isNotEmpty) {
      data['applicationStartDateText'] = job.applicationStartDateText;
    }
    if (job.applicationEndDate != null) {
      data['applicationEndDate'] =
          Timestamp.fromDate(job.applicationEndDate!);
    }
    if (job.applicationEndDateText.isNotEmpty) {
      data['applicationEndDateText'] = job.applicationEndDateText;
    }

    return data;
  }
}