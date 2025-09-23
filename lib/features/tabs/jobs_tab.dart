import 'package:flutter/material.dart';

import 'tabs_shared.dart';

class JobsTab extends StatelessWidget {
  const JobsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      children: const [
        SectionHeader(title: '전체 공고'),
        SizedBox(height: 8),
        JobMiniCard(title: 'iOS 엔지니어', company: '오로라랩스', tag: '경력 3~6년'),
        SizedBox(height: 8),
        JobMiniCard(title: '데이터 분석가', company: '하모니', tag: '신입/주니어'),
        SizedBox(height: 8),
        JobMiniCard(title: '백엔드(Java)', company: '클라우드웨이브', tag: '경력 2~5년'),
      ],
    );
  }
}
