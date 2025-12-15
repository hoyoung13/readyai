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

enum ResumeDocKind { resume, coverLetter }

class ResumeFile {
  const ResumeFile({
    required this.id,
    required this.filename,
    required this.url,
    required this.uploadedAt,
    required this.fileType,
    this.fileSize,
    this.storagePath,
    this.docKind = ResumeDocKind.resume,
    this.ai,
  });

  final String id;
  final String filename;
  final String url;
  final DateTime uploadedAt;
  final ResumeFileType fileType;
  final int? fileSize;
  final String? storagePath;
  final ResumeDocKind docKind;
  final ResumeAiMetadata? ai;

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
        'docKind': docKind.name,
        if (ai != null) 'ai': ai!.toMap(),
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
      docKind: ResumeDocKind.values.firstWhere(
        (kind) => kind.name == (data['docKind'] as String? ?? 'resume'),
        orElse: () => ResumeDocKind.resume,
      ),
      ai: data['ai'] is Map<String, dynamic>
          ? ResumeAiMetadata.fromMap(data['ai'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ResumeAiMetadata {
  const ResumeAiMetadata({
    required this.evaluatedAt,
    required this.overallScore,
    required this.reportJson,
    required this.improvedVersion,
  });

  final DateTime evaluatedAt;
  final int overallScore;
  final Map<String, dynamic> reportJson;
  final String improvedVersion;

  factory ResumeAiMetadata.fromMap(Map<String, dynamic> map) {
    final evaluatedAt = map['evaluatedAt'];
    return ResumeAiMetadata(
      evaluatedAt: evaluatedAt is Timestamp
          ? evaluatedAt.toDate()
          : DateTime.tryParse(evaluatedAt?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
      overallScore: (map['overallScore'] as num?)?.toInt() ?? 0,
      reportJson: (map['reportJson'] as Map<String, dynamic>? ?? {}),
      improvedVersion: map['improvedVersion'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'evaluatedAt': Timestamp.fromDate(evaluatedAt),
        'overallScore': overallScore,
        'reportJson': reportJson,
        'improvedVersion': improvedVersion,
      };
}
