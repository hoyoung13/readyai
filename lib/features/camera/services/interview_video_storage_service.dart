import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

class UploadedInterviewVideo {
  UploadedInterviewVideo({
    required this.storagePath,
    required this.downloadUrl,
  });

  final String storagePath;
  final String downloadUrl;
}

class InterviewVideoStorageService {
  InterviewVideoStorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<UploadedInterviewVideo> uploadVideo({
    required String localFilePath,
    required String userId,
    required String categoryKey,
  }) async {
    final file = File(localFilePath);
    if (!await file.exists()) {
      throw const InterviewVideoUploadException(
        '녹화 파일을 찾을 수 없습니다.',
      );
    }

    final extension = p.extension(localFilePath).ifEmpty(() => '.mp4');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'interview_$timestamp$extension';

    final ref = _storage
        .ref()
        .child('users')
        .child(userId)
        .child('interviews')
        .child(categoryKey)
        .child(fileName);

    try {
      final metadata = SettableMetadata(contentType: 'video/mp4');
      final task = ref.putFile(file, metadata);
      await task.whenComplete(() {});
      final url = await ref.getDownloadURL();
      return UploadedInterviewVideo(
        storagePath: ref.fullPath,
        downloadUrl: url,
      );
    } on FirebaseException catch (error) {
      throw InterviewVideoUploadException(
        '영상 업로드 중 오류가 발생했습니다. (${error.code})',
      );
    } catch (error) {
      throw InterviewVideoUploadException(
        '영상 업로드 중 알 수 없는 오류가 발생했습니다.',
      );
    }
  }
}

class InterviewVideoUploadException implements Exception {
  const InterviewVideoUploadException(this.message);

  final String message;

  @override
  String toString() => 'InterviewVideoUploadException: $message';
}

extension on String {
  String ifEmpty(String Function() orElse) {
    if (isEmpty) {
      return orElse();
    }
    return this;
  }
}
