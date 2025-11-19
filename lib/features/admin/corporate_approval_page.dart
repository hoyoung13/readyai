/// 대기 중인 기업 계정을 검토해 승인·거절하는 관리자 UI.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'corporate_approval_service.dart';

class CorporateApprovalPage extends StatefulWidget {
  const CorporateApprovalPage({super.key});

  @override
  State<CorporateApprovalPage> createState() => _CorporateApprovalPageState();
}

class _CorporateApprovalPageState extends State<CorporateApprovalPage> {
  final _service = CorporateApprovalService();
  CorporateApplicant? _selected;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('기업 회원 승인 관리'),
      ),
      body: StreamBuilder<List<CorporateApplicant>>(
        stream: _service.watchPendingApplicants(),
        builder: (context, snapshot) {
          final applicants = snapshot.data ?? const <CorporateApplicant>[];

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('대기중인 신청을 불러오지 못했습니다.\n${snapshot.error}'),
              ),
            );
          }

          if (applicants.isEmpty) {
            return const Center(child: Text('승인 대기 중인 기업 회원이 없습니다.'));
          }

          final hasSelection = _selected != null &&
              applicants.any((applicant) => applicant.uid == _selected!.uid);
          if (!hasSelection) {
            _selected = applicants.first;
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 720;
              return isWide
                  ? Row(
                      children: [
                        Expanded(child: _buildList(applicants)),
                        const VerticalDivider(width: 1),
                        Expanded(child: _buildDetail(_selected!)),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(child: _buildList(applicants)),
                        const Divider(height: 1),
                        if (_selected != null)
                          SizedBox(
                            height: 360,
                            child: _buildDetail(_selected!),
                          ),
                      ],
                    );
            },
          );
        },
      ),
    );
  }

  Widget _buildList(List<CorporateApplicant> applicants) {
    return ListView.separated(
      itemCount: applicants.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final applicant = applicants[index];
        final selected = _selected?.uid == applicant.uid;
        return ListTile(
          title: Text(applicant.companyName.isNotEmpty
              ? applicant.companyName
              : applicant.name),
          subtitle: Text(applicant.email),
          trailing: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(applicant.businessNumber.isEmpty
                  ? '미승인'
                  : applicant.businessNumber),
              const SizedBox(height: 4),
              Text(
                applicant.source == CorporateApplicantSource.corporateSignups
                    ? '신청서'
                    : '프로필',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          selected: selected,
          onTap: () => setState(() => _selected = applicant),
        );
      },
    );
  }

  Widget _buildDetail(CorporateApplicant applicant) {
    String formatDate(Timestamp? ts) {
      if (ts == null) return '기록 없음';
      final d = ts.toDate();
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      applicant.companyName.isNotEmpty
                          ? applicant.companyName
                          : applicant.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Chip(
                    label: Text(
                      applicant.source ==
                              CorporateApplicantSource.corporateSignups
                          ? '신청서 기반'
                          : '프로필 기반',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _infoRow('이메일', applicant.email),
              _infoRow('대표자명', applicant.name),
              _infoRow(
                  '사업자등록번호',
                  applicant.businessNumber.isEmpty
                      ? '-'
                      : applicant.businessNumber),
              _infoRow('신청일', formatDate(applicant.createdAt)),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade400,
                      ),
                      onPressed: _submitting
                          ? null
                          : () => _updateApproval(applicant, false),
                      icon: const Icon(Icons.close),
                      label: const Text('거절'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                      ),
                      onPressed: _submitting
                          ? null
                          : () => _updateApproval(applicant, true),
                      icon: const Icon(Icons.check),
                      label: const Text('승인'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value.isEmpty ? '-' : value),
          ),
        ],
      ),
    );
  }

  Future<void> _updateApproval(
    CorporateApplicant applicant,
    bool approved,
  ) async {
    setState(() => _submitting = true);
    try {
      await _service.setApproval(applicant: applicant, approved: approved);
      if (!mounted) return;
      final verb = approved ? '승인' : '거절';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('기업 회원을 $verb 처리했습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('처리 중 오류가 발생했습니다. $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
