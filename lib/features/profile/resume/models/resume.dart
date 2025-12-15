import 'package:cloud_firestore/cloud_firestore.dart';

enum ResumeFileType {
  pdf,
  hwp;

  static ResumeFileType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pdf':
        return ResumeFileType.pdf;
      case 'hwp':
        return ResumeFileType.hwp;
      default:
        return ResumeFileType.pdf;
    }
  }

  String get name => toString().split('.').last;
}

class ResumeFile {
  const ResumeFile({
    required this.id,
    required this.filename,
    required this.url,
    required this.uploadedAt,
    required this.fileType,
    this.fileSize,
    this.storagePath,
  });

  final String id;
  final String filename;
  final String url;
  final DateTime uploadedAt;
  final ResumeFileType fileType;
  final int? fileSize;
  final String? storagePath;

  String get formattedDate =>
      '${uploadedAt.year}-${uploadedAt.month.toString().padLeft(2, '0')}-${uploadedAt.day.toString().padLeft(2, '0')}';

  String get formattedSize {
    final size = fileSize;
    if (size == null) return '';
    if (size >= 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    if (size >= 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }

    return '$size B';
  }

  Map<String, dynamic> toMap() => {
        'filename': filename,
        'url': url,
        'uploadedAt': Timestamp.fromDate(uploadedAt),
        'fileType': fileType.name,
        'fileSize': fileSize,
        'storagePath': storagePath,
      };

  factory ResumeFile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final uploadedAt = data['uploadedAt'];
    return ResumeFile(
      id: doc.id,
      filename: (data['filename'] as String?) ?? '',
      url: (data['url'] as String?) ?? '',
      uploadedAt: uploadedAt is Timestamp
          ? uploadedAt.toDate()
          : DateTime.tryParse(uploadedAt?.toString() ?? '') ?? DateTime.now(),
      fileType:
          ResumeFileType.fromString((data['fileType'] as String?) ?? 'pdf'),
      fileSize: (data['fileSize'] as num?)?.toInt(),
      storagePath: data['storagePath'] as String?,
    );
  }
}
