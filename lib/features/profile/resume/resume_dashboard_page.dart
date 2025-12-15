import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ai/features/profile/resume/data/resume_repository.dart';
import 'package:ai/features/profile/resume/models/resume.dart';
import 'package:ai/features/tabs/tabs_shared.dart';

class ResumeDashboardPage extends StatefulWidget {
  const ResumeDashboardPage({super.key});

  @override
  State<ResumeDashboardPage> createState() => _ResumeDashboardPageState();
}

class _ResumeDashboardPageState extends State<ResumeDashboardPage> {
  final _repository = ResumeRepository.instance();
  List<ResumeFile> _resumes = const [];
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadResumes();
  }

  Future<void> _loadResumes() async {
    final userId = _repository.currentUserId();
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _resumes = const [];
      });
      return;
    }
    final resumes = await _repository.fetchAll(userId);
    if (!mounted) return;
    setState(() {
      _resumes = resumes;
      _isLoading = false;
    });
  }

  Future<void> _pickAndUpload() async {
    if (_isUploading) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'hwp'],
      withData: kIsWeb,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    final bytes = file.bytes ?? await File(file.path!).readAsBytes();
    final extension = (file.extension ?? '').toLowerCase();
    final fileType =
        extension == 'hwp' ? ResumeFileType.hwp : ResumeFileType.pdf;

    setState(() => _isUploading = true);

    try {
      await _repository.uploadResumeFile(
        userId: user.uid,
        filename: file.name,
        bytes: Uint8List.fromList(bytes),
        fileType: fileType,
      );
      await _loadResumes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이력서가 업로드되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('업로드에 실패했습니다: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('이력서'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0.5,
        actions: [
          TextButton.icon(
            onPressed: _isUploading ? null : _pickAndUpload,
            icon: const Icon(Icons.upload_file),
            label: const Text('업로드'),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_resumes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: _ResumeEmptyState(onUpload: _pickAndUpload),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadResumes,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        itemBuilder: (_, index) => _ResumeFileTile(
          resume: _resumes[index],
          onView: () =>
              context.push('/profile/resume/view', extra: _resumes[index]),
        ),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemCount: _resumes.length,
      ),
    );
  }
}

class _ResumeFileTile extends StatelessWidget {
  const _ResumeFileTile({required this.resume, required this.onView});

  final ResumeFile resume;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resume.filename,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _InfoChip(label: resume.fileType.name.toUpperCase()),
                    const SizedBox(width: 8),
                    Text(
                      '업로드일 ${resume.formattedDate}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.subtext),
                    ),
                    if (resume.formattedSize.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        resume.formattedSize,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.subtext),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: onView,
            child: const Text('보기'),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5FB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
      ),
    );
  }
}

class _ResumeEmptyState extends StatelessWidget {
  const _ResumeEmptyState({required this.onUpload});

  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E1E5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.upload_file_outlined,
            color: AppColors.subtext,
            size: 40,
          ),
          const SizedBox(height: 16),
          const Text(
            '업로드된 이력서가 없습니다.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.subtext,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onUpload,
            child: const Text('이력서 업로드'),
          ),
        ],
      ),
    );
  }
}
