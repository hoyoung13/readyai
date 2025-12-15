import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:ai/features/profile/resume/ai/resume_ai_models.dart';
import 'package:ai/features/profile/resume/ai/resume_ai_service.dart';
import 'package:ai/features/profile/resume/models/resume.dart';

class ResumeRepository {
  ResumeRepository._(this._firestore, this._storage)
      : _aiService = ResumeAiService();

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final ResumeAiService _aiService;

  static ResumeRepository? _instance;

  static ResumeRepository instance() {
    return _instance ??= ResumeRepository._(
      FirebaseFirestore.instance,
      FirebaseStorage.instance,
    );
  }

  CollectionReference<Map<String, dynamic>> _resumeCollection(String userId) {
    return _firestore.collection('users').doc(userId).collection('resumes');
  }

  Future<List<ResumeFile>> fetchAll(String userId) async {
    final snapshot = await _resumeCollection(userId)
        .orderBy('uploadedAt', descending: true)
        .get();
    return snapshot.docs.map(ResumeFile.fromDoc).toList();
  }

  Future<ResumeFile> uploadResumeFile({
    required String userId,
    required String filename,
    required Uint8List bytes,
    required ResumeFileType fileType,
  }) async {
    final docRef = _resumeCollection(userId).doc();
    final extension = filename.split('.').last;
    final storagePath = 'users/$userId/resumes/${docRef.id}.$extension';
    final storageRef = _storage.ref().child(storagePath);

    final metadata = SettableMetadata(
      contentType: fileType == ResumeFileType.pdf
          ? 'application/pdf'
          : 'application/haansofthwp',
    );

    if (kIsWeb) {
      await storageRef.putData(bytes, metadata);
    } else {
      final tempFile = await _writeTempFile(bytes, docRef.id, extension);
      await storageRef.putFile(tempFile, metadata);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }

    final url = await storageRef.getDownloadURL();
    final uploadedAt = DateTime.now();

    await docRef.set({
      'filename': filename,
      'url': url,
      'uploadedAt': uploadedAt,
      'fileType': fileType.name,
      'fileSize': bytes.lengthInBytes,
      'storagePath': storagePath,
      'docKind': ResumeDocKind.resume.name,
    });

    return ResumeFile(
      id: docRef.id,
      filename: filename,
      url: url,
      uploadedAt: uploadedAt,
      fileType: fileType,
      fileSize: bytes.lengthInBytes,
      storagePath: storagePath,
      docKind: ResumeDocKind.resume,
    );
  }

  Future<ProcessedDocumentResult> processDocument({
    required ResumeFile resume,
    required ResumeDocKind docKind,
    String language = 'ko',
    String? targetRole,
  }) async {
    return _aiService.processDocument(
      fileUrl: resume.url,
      fileType: resume.fileType.name,
      docKind: docKind,
      language: language,
      targetRole: targetRole,
    );
  }

  Future<EvaluationResponse> evaluate({
    required String extractedText,
    required ResumeFile resume,
    required ResumeDocKind docKind,
    String language = 'ko',
    String? targetRole,
  }) async {
    final evaluation = await _aiService.evaluate(
      extractedText: extractedText,
      docKind: docKind,
      language: language,
      targetRole: targetRole,
    );

    final userId = currentUserId();
    if (userId != null) {
      await _resumeCollection(userId).doc(resume.id).set({
        'ai': {
          'evaluatedAt': DateTime.now().toIso8601String(),
          'overallScore': evaluation.report.overallScore,
          'reportJson': evaluation.report.toJson(),
          'improvedVersion': evaluation.improvedVersion,
        },
      }, SetOptions(merge: true));
    }

    return evaluation;
  }

  Future<SummaryResult> summarize({
    required String extractedText,
    String language = 'ko',
  }) async {
    return _aiService.summarize(
        extractedText: extractedText, language: language);
  }

  Future<ProofreadResult> proofread({
    required String extractedText,
    String language = 'ko',
    String? targetRole,
  }) async {
    return _aiService.proofread(
      extractedText: extractedText,
      language: language,
      targetRole: targetRole,
    );
  }

  Future<void> updateDocKind({
    required String resumeId,
    required ResumeDocKind docKind,
  }) async {
    final userId = currentUserId();
    if (userId == null) return;
    await _resumeCollection(userId).doc(resumeId).set({
      'docKind': docKind.name,
    }, SetOptions(merge: true));
  }

  Future<File> _writeTempFile(Uint8List bytes, String id, String ext) async {
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/$id.$ext');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  String? currentUserId() => FirebaseAuth.instance.currentUser?.uid;
}
