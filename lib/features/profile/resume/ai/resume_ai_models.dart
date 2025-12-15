import 'dart:convert';

import 'package:ai/features/profile/resume/models/resume.dart';

class ProcessedDocumentResult {
  const ProcessedDocumentResult({
    required this.extractedText,
    required this.pageCount,
    this.pdfUrl,
  });

  final String extractedText;
  final int pageCount;
  final String? pdfUrl;

  factory ProcessedDocumentResult.fromJson(Map<String, dynamic> json) {
    return ProcessedDocumentResult(
      extractedText: json['extractedText'] as String? ?? '',
      pageCount: (json['pageCount'] as num?)?.toInt() ?? 0,
      pdfUrl: json['pdfUrl'] as String?,
    );
  }
}

class RubricScores {
  const RubricScores({
    required this.readability,
    required this.impact,
    required this.structure,
    required this.specificity,
    required this.roleFit,
  });

  final int readability;
  final int impact;
  final int structure;
  final int specificity;
  final int roleFit;

  factory RubricScores.fromJson(Map<String, dynamic> json) {
    return RubricScores(
      readability: (json['readability'] as num?)?.toInt() ?? 0,
      impact: (json['impact'] as num?)?.toInt() ?? 0,
      structure: (json['structure'] as num?)?.toInt() ?? 0,
      specificity: (json['specificity'] as num?)?.toInt() ?? 0,
      roleFit: (json['roleFit'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'readability': readability,
        'impact': impact,
        'structure': structure,
        'specificity': specificity,
        'roleFit': roleFit,
      };
}

class ActionableEdit {
  const ActionableEdit({
    required this.section,
    required this.issue,
    required this.suggestion,
  });

  final String section;
  final String issue;
  final String suggestion;

  factory ActionableEdit.fromJson(Map<String, dynamic> json) => ActionableEdit(
        section: json['section'] as String? ?? '',
        issue: json['issue'] as String? ?? '',
        suggestion: json['suggestion'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'section': section,
        'issue': issue,
        'suggestion': suggestion,
      };
}

class EvaluationReport {
  const EvaluationReport({
    required this.overallScore,
    required this.rubricScores,
    required this.strengths,
    required this.weaknesses,
    required this.actionableEdits,
    required this.redFlags,
    required this.summary,
  });

  final int overallScore;
  final RubricScores rubricScores;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<ActionableEdit> actionableEdits;
  final List<String> redFlags;
  final String summary;

  factory EvaluationReport.fromJson(Map<String, dynamic> json) =>
      EvaluationReport(
        overallScore: (json['overallScore'] as num?)?.toInt() ?? 0,
        rubricScores: RubricScores.fromJson(
            (json['rubricScores'] as Map<String, dynamic>? ?? {})),
        strengths: List<String>.from(json['strengths'] as List? ?? const []),
        weaknesses: List<String>.from(json['weaknesses'] as List? ?? const []),
        actionableEdits: (json['actionableEdits'] as List? ?? const [])
            .map((e) => ActionableEdit.fromJson(e as Map<String, dynamic>))
            .toList(),
        redFlags: List<String>.from(json['redFlags'] as List? ?? const []),
        summary: json['summary'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'overallScore': overallScore,
        'rubricScores': rubricScores.toJson(),
        'strengths': strengths,
        'weaknesses': weaknesses,
        'actionableEdits': actionableEdits.map((e) => e.toJson()).toList(),
        'redFlags': redFlags,
        'summary': summary,
      };
}

class EvaluationResponse {
  const EvaluationResponse(
      {required this.report, required this.improvedVersion});

  final EvaluationReport report;
  final String improvedVersion;

  factory EvaluationResponse.fromJson(Map<String, dynamic> json) =>
      EvaluationResponse(
        report: EvaluationReport.fromJson(
            json['report'] as Map<String, dynamic>? ?? {}),
        improvedVersion: json['improvedVersion'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'report': report.toJson(),
        'improvedVersion': improvedVersion,
      };
}

class SummaryResult {
  const SummaryResult({
    required this.bulletSummary,
    required this.oneLiner,
    required this.keywords,
  });

  final List<String> bulletSummary;
  final String oneLiner;
  final List<String> keywords;

  factory SummaryResult.fromJson(Map<String, dynamic> json) => SummaryResult(
        bulletSummary:
            List<String>.from(json['bulletSummary'] as List? ?? const []),
        oneLiner: json['oneLiner'] as String? ?? '',
        keywords: List<String>.from(json['keywords'] as List? ?? const []),
      );
}

class ProofreadComment {
  const ProofreadComment({required this.lineOrSection, required this.comment});

  final String lineOrSection;
  final String comment;

  factory ProofreadComment.fromJson(Map<String, dynamic> json) =>
      ProofreadComment(
        lineOrSection: json['lineOrSection'] as String? ?? '',
        comment: json['comment'] as String? ?? '',
      );
}

class ProofreadResult {
  const ProofreadResult({required this.correctedText, required this.comments});

  final String correctedText;
  final List<ProofreadComment> comments;

  factory ProofreadResult.fromJson(Map<String, dynamic> json) =>
      ProofreadResult(
        correctedText: json['correctedText'] as String? ?? '',
        comments: (json['comments'] as List? ?? const [])
            .map((e) => ProofreadComment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ResumeAiPayload {
  const ResumeAiPayload({
    required this.docKind,
    required this.language,
    this.targetRole,
  });

  final ResumeDocKind docKind;
  final String language;
  final String? targetRole;
}

class AiStoredResult {
  const AiStoredResult({
    required this.evaluatedAt,
    required this.overallScore,
    required this.reportJson,
    required this.improvedVersion,
  });

  final DateTime evaluatedAt;
  final int overallScore;
  final Map<String, dynamic> reportJson;
  final String improvedVersion;

  factory AiStoredResult.fromMap(Map<String, dynamic> data) {
    return AiStoredResult(
      evaluatedAt: DateTime.tryParse((data['evaluatedAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      overallScore: (data['overallScore'] as num?)?.toInt() ?? 0,
      reportJson: (data['reportJson'] as Map<String, dynamic>? ?? {}),
      improvedVersion: data['improvedVersion'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'evaluatedAt': evaluatedAt.toIso8601String(),
        'overallScore': overallScore,
        'reportJson': reportJson,
        'improvedVersion': improvedVersion,
      };
}

String encodeReport(Map<String, dynamic> report) => jsonEncode(report);
Map<String, dynamic> decodeReport(String encoded) =>
    jsonDecode(encoded) as Map<String, dynamic>;
