import 'package:flutter/material.dart';

import '../jobs/job_detail_page.dart';
import '../jobs/job_posting.dart';
import 'tabs_shared.dart';

class JobsTab extends StatelessWidget {
  const JobsTab({super.key});

  @override
  Widget build(BuildContext context) {
    const totalCount = _totalJobCount;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
      children: const [
        _Header(totalCount: totalCount),
        SizedBox(height: 24),
        _FilterPanel(),
        SizedBox(height: 24),
        _JobSummaryBoard(),
        SizedBox(height: 32),
        _JobSection(),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.totalCount});

  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const CircleAvatar(
                backgroundImage: AssetImage('assets/logo.png'),
                backgroundColor: Colors.transparent,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Ai',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '채용공고',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          '채용정보 총 ${totalCount}건',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '지금 뜨는 IT 채용 공고를 빠르게 확인하세요.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.subtext,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _FilterRow(),
          SizedBox(height: 12),
          _FilterNotice(),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _FilterMenuButton(
          icon: Icons.badge_outlined,
          label: '직업 선택',
        ),
        SizedBox(width: 12),
        _FilterMenuButton(
          icon: Icons.place_outlined,
          label: '지역 선택',
        ),
        SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _SearchField(),
        ),
      ],
    );
  }
}

class _FilterMenuButton extends StatelessWidget {
  const _FilterMenuButton({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F3F6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.subtext),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.subtext),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: const [
          Icon(Icons.search, size: 18, color: AppColors.subtext),
          SizedBox(width: 8),
          Text(
            '검색어 입력',
            style: TextStyle(
              color: AppColors.subtext,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterNotice extends StatelessWidget {
  const _FilterNotice();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Icon(Icons.info_outline, size: 16, color: AppColors.subtext),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            '필터 기능은 준비 중입니다. 지금은 추천 공고를 확인해 보세요.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.subtext,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _JobSummaryBoard extends StatelessWidget {
  const _JobSummaryBoard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Container(
              color: const Color(0xFFEAF0FF),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: const [
                  Icon(Icons.auto_awesome, color: Color(0xFF4C6EF5)),
                  SizedBox(width: 8),
                  Text(
                    '이번 주 인기 포지션 요약',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Spacer(),
                  Text(
                    '업데이트 09:00',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.subtext,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: const Color(0xFF4C6EF5),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: const [
                  _SummaryHeaderCell('기업', flex: 1),
                  _SummaryHeaderCell('직무', flex: 2),
                  _SummaryHeaderCell('지역', flex: 1),
                  _SummaryHeaderCell('상태', flex: 1),
                ],
              ),
            ),
            for (var i = 0; i < _summaryRows.length; i++)
              Container(
                color: i.isEven ? Colors.white : const Color(0xFFF5F7FF),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    _SummaryCell(_summaryRows[i][0], flex: 1),
                    _SummaryCell(_summaryRows[i][1], flex: 2),
                    _SummaryCell(_summaryRows[i][2], flex: 1),
                    _SummaryCell(_summaryRows[i][3], flex: 1, alignEnd: true),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryHeaderCell extends StatelessWidget {
  const _SummaryHeaderCell(this.text, {required this.flex});

  final String text;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell(this.text, {required this.flex, this.alignEnd = false});

  final String text;
  final int flex;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
      ),
    );
  }
}

class _JobSection extends StatelessWidget {
  const _JobSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          '이 공고, 놓치지 마세요!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 16),
        _JobsGrid(),
      ],
    );
  }
}

class _JobsGrid extends StatelessWidget {
  const _JobsGrid();

  static const _cardColors = [
    Color(0xFFEF5350),
    Color(0xFF7E57C2),
    Color(0xFF26A69A),
    Color(0xFF42A5F5),
    Color(0xFFFFCA28),
    Color(0xFFAB47BC),
    Color(0xFF5C6BC0),
    Color(0xFFFF7043),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        int crossAxisCount = 1;
        if (maxWidth >= 640) {
          crossAxisCount = 3;
        } else if (maxWidth >= 420) {
          crossAxisCount = 2;
        }

        final aspectRatio = crossAxisCount == 1 ? 2.0 : 0.95;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _feed.items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: aspectRatio,
          ),
          itemBuilder: (context, index) {
            final job = _feed.items[index];
            final color = _cardColors[index % _cardColors.length];
            return _JobCard(job: job, color: color);
          },
        );
      },
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.color});

  final JobPosting job;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => JobDetailPage(job: job)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    job.companyLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  job.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  job.tagsSummary,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        job.regionLabel,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.92),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (job.prettyPostedDate != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: Colors.white.withOpacity(0.85),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${job.prettyPostedDate} 기준',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

const int _totalJobCount = 111;

const List<List<String>> _summaryRows = [
  ['Acme Corp', '프론트엔드 엔지니어', '서울 강남', '모집 중'],
  ['K-Tech', 'iOS 엔지니어', '경기 성남', '서류 진행'],
  ['MegaBank', '데이터 엔지니어', '서울 을지로', '인터뷰 진행'],
  ['Saewo', '프로덕트 디자이너', '부산 해운대', '채용 중'],
  ['Shinhan Bank', '백엔드 개발자', '서울 중구', '모집 마감 D-3'],
];

const List<JobPosting> _mockJobs = [
  JobPosting(
    title: '프론트엔드 엔지니어',
    company: 'Acme Corp',
    region: '서울특별시 강남구',
    url: 'https://jobs.example.com/acme-frontend',
    postedDateText: '2025-02-05',
    tags: ['정규직', '신입·경력', '연봉 협상'],
    summaryItems: [
      JobSummaryItem(label: '경력', value: '무관 (신입 포함)'),
      JobSummaryItem(label: '기술스택', value: 'React · TypeScript'),
      JobSummaryItem(label: '근무형태', value: '하이브리드 근무'),
      JobSummaryItem(label: '학력', value: '학력 무관'),
    ],
    detailRows: [
      JobDetailRow(
        title: '담당업무',
        description: '웹 프론트엔드 신규 기능 개발과 디자인 시스템 고도화',
      ),
      JobDetailRow(
        title: '자격요건',
        description: 'React 실무 2년 이상, 협업 도구 활용 경험',
      ),
      JobDetailRow(
        title: '우대사항',
        description: '대규모 트래픽 서비스 운영 경험 보유자',
      ),
      JobDetailRow(
        title: '근무시간',
        description: '주 5일, 자율 출퇴근(09:00~11:00)',
      ),
    ],
    description: '사용자 경험을 최우선으로 생각하는 프로덕트 팀과 협업하며 대규모 서비스를 함께 만들어 갑니다.',
    notice: '이력서와 포트폴리오(PDF)를 함께 제출해 주세요.',
  ),
  JobPosting(
    title: 'iOS 엔지니어',
    company: 'K-Tech',
    region: '경기도 성남시 분당구',
    url: 'https://jobs.example.com/ktech-ios',
    postedDateText: '2025-02-02',
    tags: ['정규직', '3년 이상', '스톡옵션'],
    summaryItems: [
      JobSummaryItem(label: '경력', value: '3~7년'),
      JobSummaryItem(label: '기술스택', value: 'Swift · SwiftUI'),
      JobSummaryItem(label: '근무지', value: '판교 R&D 센터'),
      JobSummaryItem(label: '복지', value: '자율 복지 포인트 연 200만 원'),
    ],
    detailRows: [
      JobDetailRow(
        title: '담당업무',
        description: '모바일 뱅킹 iOS 앱 신규 기능 설계 및 구현',
      ),
      JobDetailRow(
        title: '자격요건',
        description: 'Swift 기반 앱 개발 3년 이상, MVVM 패턴 이해',
      ),
      JobDetailRow(
        title: '우대사항',
        description: 'CI/CD 구축 경험, TestFlight 배포 경험',
      ),
      JobDetailRow(
        title: '기타',
        description: '입사 시 스톡옵션 및 리모트 근무 주 2회 제공',
      ),
    ],
    description: '핀테크 시장을 선도하는 모바일 앱을 함께 만들 iOS 전문가를 찾고 있습니다.',
    notice: '포트폴리오 링크와 함께 주요 기여도를 구체적으로 작성해 주세요.',
  ),
  JobPosting(
    title: '데이터 엔지니어',
    company: 'MegaBank',
    region: '서울특별시 중구 을지로',
    url: 'https://jobs.example.com/megabank-data',
    postedDateText: '2025-01-28',
    tags: ['정규직', '5년 이상', '리모트 가능'],
    summaryItems: [
      JobSummaryItem(label: '경력', value: '5년 이상'),
      JobSummaryItem(label: '기술스택', value: 'Spark · Airflow'),
      JobSummaryItem(label: '근무형태', value: '원격+오피스 병행'),
      JobSummaryItem(label: '연봉', value: '최대 1억 2천만 원'),
    ],
    detailRows: [
      JobDetailRow(
        title: '담당업무',
        description: '데이터 파이프라인 설계·구축 및 MLOps 환경 운영',
      ),
      JobDetailRow(
        title: '자격요건',
        description: '대용량 데이터 처리 경험, Python 능숙자',
      ),
      JobDetailRow(
        title: '우대사항',
        description: '금융권 데이터 레이크 구축 경험 보유자',
      ),
      JobDetailRow(
        title: '근무시간',
        description: '주 1회 재택, 코어타임 10:00~16:00',
      ),
    ],
    description: '전사 데이터 플랫폼을 구축하여 인사이트를 발굴하고 안정적인 운영을 함께할 분을 찾습니다.',
    notice: '기술 블로그나 발표 자료가 있다면 함께 첨부해 주세요.',
  ),
  JobPosting(
    title: '프로덕트 디자이너',
    company: 'Saewo',
    region: '부산광역시 해운대구',
    url: 'https://jobs.example.com/saewo-design',
    postedDateText: '2025-02-01',
    tags: ['정규직', '신입·경력', '원격 협업'],
    summaryItems: [
      JobSummaryItem(label: '경력', value: '1~5년'),
      JobSummaryItem(label: '툴', value: 'Figma · Protopie'),
      JobSummaryItem(label: '근무형태', value: '원격 + 부산 오피스'),
      JobSummaryItem(label: '복지', value: '컨퍼런스 및 교육비 전액 지원'),
    ],
    detailRows: [
      JobDetailRow(
        title: '담당업무',
        description: '모바일·웹 서비스 UX 설계 및 UI 디자인 가이드 제작',
      ),
      JobDetailRow(
        title: '자격요건',
        description: '사용자 리서치 경험, 협업 툴(Jira, Slack) 활용',
      ),
      JobDetailRow(
        title: '우대사항',
        description: '프로덕트 런칭 경험 혹은 스타트업 근무 경험',
      ),
      JobDetailRow(
        title: '기타',
        description: '디자인 챕터 전용 성장 프로그램 제공',
      ),
    ],
    description: '새로운 교육 플랫폼의 디자인 방향성을 함께 고민하고 구현해 나갈 디자이너를 기다립니다.',
    notice: '포트폴리오 PDF 또는 웹사이트 링크를 제출해 주세요.',
  ),
  JobPosting(
    title: '백엔드 개발자',
    company: 'Shinhan Bank',
    region: '서울특별시 중구',
    url: 'https://jobs.example.com/shinhan-backend',
    postedDateText: '2025-01-30',
    tags: ['정규직', '4년 이상', '대기업 복지'],
    summaryItems: [
      JobSummaryItem(label: '경력', value: '4년 이상'),
      JobSummaryItem(label: '기술스택', value: 'Java · Spring'),
      JobSummaryItem(label: '근무지', value: '을지로 본사'),
      JobSummaryItem(label: '근무형태', value: '주 2일 재택'),
    ],
    detailRows: [
      JobDetailRow(
        title: '담당업무',
        description: '인터넷뱅킹 핵심 서비스 백엔드 개발 및 운영',
      ),
      JobDetailRow(
        title: '자격요건',
        description: 'Spring Boot 기반 서비스 개발 4년 이상',
      ),
      JobDetailRow(
        title: '우대사항',
        description: '클라우드 환경(AWS, GCP) 운영 경험',
      ),
      JobDetailRow(
        title: '기타',
        description: '성과에 따른 인센티브 및 복지 포인트 제공',
      ),
    ],
    description: '안정적인 금융 서비스를 위한 핵심 시스템을 책임질 백엔드 개발자를 모집합니다.',
    notice: '경력기술서에 담당 서비스와 역할을 구체적으로 작성해 주세요.',
  ),
  JobPosting(
    title: '머신러닝 엔지니어',
    company: '스타트업랩',
    region: '서울특별시 마포구',
    url: 'https://jobs.example.com/startuplab-ml',
    postedDateText: '2025-02-03',
    tags: ['정규직', '2년 이상', 'AI 연구'],
    summaryItems: [
      JobSummaryItem(label: '경력', value: '2~6년'),
      JobSummaryItem(label: '기술스택', value: 'PyTorch · Kubeflow'),
      JobSummaryItem(label: '근무형태', value: '주 3일 원격'),
      JobSummaryItem(label: '연구비', value: '프로젝트별 추가 지원'),
    ],
    detailRows: [
      JobDetailRow(
        title: '담당업무',
        description: '추천 시스템 및 생성형 AI 모델 연구·개발',
      ),
      JobDetailRow(
        title: '자격요건',
        description: '머신러닝 모델 서빙 경험, Python 능숙자',
      ),
      JobDetailRow(
        title: '우대사항',
        description: '대규모 언어모델 파인튜닝 경험자',
      ),
      JobDetailRow(
        title: '기타',
        description: 'GPU 실험 인프라 무제한 지원',
      ),
    ],
    description: '다양한 도메인의 데이터를 활용해 새로운 사용자 경험을 만드는 팀에 합류하게 됩니다.',
    notice: 'GitHub 혹은 연구 논문 링크를 함께 제출해 주세요.',
  ),
  JobPosting(
    title: '프로덕트 매니저',
    company: '커넥트PM',
    region: '인천광역시 연수구',
    url: 'https://jobs.example.com/connectpm',
    postedDateText: '2025-01-27',
    tags: ['정규직', '3년 이상', '원격 근무'],
    summaryItems: [
      JobSummaryItem(label: '경력', value: '3~8년'),
      JobSummaryItem(label: '도메인', value: 'B2B SaaS'),
      JobSummaryItem(label: '근무형태', value: '완전 원격'),
      JobSummaryItem(label: '채용형태', value: '연봉 협상 + 스톡옵션'),
    ],
    detailRows: [
      JobDetailRow(
        title: '담당업무',
        description: '제품 로드맵 수립, 데이터 기반 의사결정 리딩',
      ),
      JobDetailRow(
        title: '자격요건',
        description: '프로덕트 매니징 경험 3년 이상, 커뮤니케이션 역량',
      ),
      JobDetailRow(
        title: '우대사항',
        description: 'B2B SaaS 기획 및 런칭 경험',
      ),
      JobDetailRow(
        title: '기타',
        description: 'OKR 기반 목표 관리, 원격 팀 협업',
      ),
    ],
    description: '국내 시장을 넘어 글로벌 SaaS 제품을 함께 성장시킬 PM을 찾습니다.',
    notice: '직전 프로젝트의 성과를 수치로 기재해 주세요.',
  ),
  JobPosting(
    title: '클라우드 플랫폼 엔지니어',
    company: 'SkyOps',
    region: '대전광역시 유성구',
    url: 'https://jobs.example.com/skyops-cloud',
    postedDateText: '2025-02-04',
    tags: ['정규직', '4년 이상', '재택 선택'],
    summaryItems: [
      JobSummaryItem(label: '경력', value: '4년 이상'),
      JobSummaryItem(label: '기술스택', value: 'AWS · Terraform'),
      JobSummaryItem(label: '근무형태', value: '선택적 재택 근무'),
      JobSummaryItem(label: '근무지', value: '대전 본사'),
    ],
    detailRows: [
      JobDetailRow(
        title: '담당업무',
        description: '클라우드 인프라 설계, IaC 자동화 및 운영',
      ),
      JobDetailRow(
        title: '자격요건',
        description: 'AWS 아키텍처 설계 경험, Terraform 활용 능력',
      ),
      JobDetailRow(
        title: '우대사항',
        description: '클라우드 보안 인증 취득자 (CKA, AWS SA 등)',
      ),
      JobDetailRow(
        title: '기타',
        description: '온보딩 후 재택 근무 선택 가능 (주 2회)',
      ),
    ],
    description: '안정성과 확장성을 동시에 갖춘 클라우드 인프라를 구축할 엔지니어를 찾고 있습니다.',
    notice: '최근 구축한 인프라 아키텍처 다이어그램을 첨부하면 좋아요.',
  ),
];

const JobFeed _feed = JobFeed(items: _mockJobs);
