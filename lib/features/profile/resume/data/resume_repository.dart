import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:ai/features/profile/resume/models/resume.dart';

class ResumeRepository {
  ResumeRepository._(this._firestore, this._storage);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

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
    });

    return ResumeFile(
      id: docRef.id,
      filename: filename,
      url: url,
      uploadedAt: uploadedAt,
      fileType: fileType,
      fileSize: bytes.lengthInBytes,
      storagePath: storagePath,
    );
  }

  Future<String> evaluateResume(String fileUrl) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    final previewLength = fileUrl.length > 30 ? 30 : fileUrl.length;
    return 'AI 평가 결과: ${fileUrl.substring(0, previewLength)} ...';
  }

  Future<File> _writeTempFile(Uint8List bytes, String id, String ext) async {
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/$id.$ext');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  String? currentUserId() => FirebaseAuth.instance.currentUser?.uid;
}
