/// 대기 중인 기업 계정을 검토해 승인·거절하는 관리자 UI.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ai/features/tabs/tabs_shared.dart';

import 'corporate_approval_service.dart';

class CorporateApprovalPage extends StatefulWidget {
  const CorporateApprovalPage({super.key});

  @override
  State<CorporateApprovalPage> createState() => _CorporateApprovalPageState();
}

class _CorporateApprovalPageState extends State<CorporateApprovalPage> {
  final _service = CorporateApprovalService();
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        title: const Text(
          '기업 계정 승인',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
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

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.check_circle_outline,
                          color: AppColors.primary),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '승인 대기 목록',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      Text(
                        '기업 계정 승인',
                        style: TextStyle(color: AppColors.subtext),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(child: _buildTable(applicants)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTable(List<CorporateApplicant> applicants) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: DataTable(
              headingRowColor:
                  MaterialStateProperty.all<Color>(AppColors.primarySoft),
              headingTextStyle: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
              dataTextStyle: const TextStyle(
                fontSize: 13,
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
              columns: const [
                DataColumn(label: Text('담당자')),
                DataColumn(label: Text('기업명')),
                DataColumn(label: Text('사업자 등록번호')),
                DataColumn(label: Text('요청일자')),
                DataColumn(label: Text('승인')),
              ],
              rows: applicants
                  .map(
                    (applicant) => DataRow(
                      cells: [
                        DataCell(Text(
                            applicant.name.isEmpty ? '정보 없음' : applicant.name)),
                        DataCell(Text(applicant.companyName.isEmpty
                            ? '-'
                            : applicant.companyName)),
                        DataCell(Text(applicant.businessNumber.isEmpty
                            ? '미등록'
                            : applicant.businessNumber)),
                        DataCell(Text(_formatDate(applicant.createdAt))),
                        DataCell(
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _submitting
                                ? null
                                : () => _updateApproval(applicant, true),
                            child: const Text('승인'),
                          ),
                        ),
                      ],
                      onSelectChanged: (_) => _showApplicantSheet(applicant),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '기록 없음';
    final d = ts.toDate();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  void _showApplicantSheet(CorporateApplicant applicant) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        applicant.companyName.isNotEmpty
                            ? applicant.companyName
                            : applicant.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Chip(
                      backgroundColor: AppColors.primarySoft,
                      label: Text(
                        applicant.source ==
                                CorporateApplicantSource.corporateSignups
                            ? '신청서'
                            : '프로필',
                        style: const TextStyle(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _detailRow('이메일', applicant.email),
                _detailRow('담당자', applicant.name),
                _detailRow(
                    '사업자등록번호',
                    applicant.businessNumber.isEmpty
                        ? '-'
                        : applicant.businessNumber),
                _detailRow('신청일', _formatDate(applicant.createdAt)),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade500,
                          side: BorderSide(color: Colors.red.shade200),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _submitting
                            ? null
                            : () async {
                                await _updateApproval(applicant, false);
                                if (mounted) Navigator.of(context).pop();
                              },
                        icon: const Icon(Icons.close),
                        label: const Text('거절'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _submitting
                            ? null
                            : () async {
                                await _updateApproval(applicant, true);
                                if (mounted) Navigator.of(context).pop();
                              },
                        icon: const Icon(Icons.check),
                        label: const Text('승인'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  '행을 탭하면 상세 정보와 승인/거절을 바로 처리할 수 있어요.',
                  style: TextStyle(color: AppColors.subtext),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.subtext,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
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
