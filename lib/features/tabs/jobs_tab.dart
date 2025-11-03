import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../jobs/job_detail_page.dart';
import '../jobs/job_posting.dart';
import '../jobs/job_posting_loader.dart';
import 'tabs_shared.dart';

class JobsTab extends StatefulWidget {
  const JobsTab({super.key});
  @override
  State<JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends State<JobsTab> {
  late Future<JobFeed> _future;
  final JobPostingLoader _loader = const JobPostingLoader();

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<JobFeed> _fetch() => _loader.load();

  Future<void> _handleRefresh() {
    final future = _fetch();
    setState(() {
      _future = future;
    });
    return future.then((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: FutureBuilder<JobFeed>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingView();
          }

          if (snapshot.hasError) {
            return _ErrorView(
              error: snapshot.error,
              onRetry: () {
                setState(() {
                  _future = _fetch();
                });
              },
            );
          }

          final feed = snapshot.data;
          if (feed == null || feed.items.isEmpty) {
            return const _EmptyView();
          }

          return _JobsList(feed: feed);
        },
      ),
    );
  }
}

class _JobsList extends StatefulWidget {
  const _JobsList({required this.feed});

  final JobFeed feed;
  @override
  State<_JobsList> createState() => _JobsListState();
}

class _JobsListState extends State<_JobsList> {
  static const _pageSize = 20;
  int _currentPage = 1;
  String? _selectedRegion;
  String? _selectedCategory;
  String _searchQuery = '';
  late final TextEditingController _searchController;
  List<String> _availableRegions = const <String>[];
  List<String> _availableCategories = const <String>[];
  List<JobPosting> _filteredItems = const <JobPosting>[];
  bool _showCategories = false;


  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _availableRegions = _collectRegions(widget.feed.items);
    _availableCategories = _collectCategories(widget.feed.items);
    _filteredItems = _filterJobs(widget.feed.items);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _JobsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.feed.items, oldWidget.feed.items) ||
        widget.feed.totalCount != oldWidget.feed.totalCount) {
      final regions = _collectRegions(widget.feed.items);
      final categories = _collectCategories(widget.feed.items);

      var nextRegion = _selectedRegion;
      if (nextRegion != null && !regions.contains(nextRegion)) {
        nextRegion = null;
      }

      var nextCategory = _selectedCategory;
      if (nextCategory != null && !categories.contains(nextCategory)) {
        nextCategory = null;
      }
      final filtered = _filterJobs(
        widget.feed.items,
        regionFilter: nextRegion,
        categoryFilter: nextCategory,
      );
      final totalPages = _pageCount(filtered.length);

      setState(() {
        _availableRegions = regions;
        _availableCategories = categories;
        _selectedRegion = nextRegion;
        _selectedCategory = nextCategory;
        _filteredItems = filtered;
        _currentPage = math.min(_currentPage, totalPages);
      });
    }
  }

  void _onPageSelected(int page) {
    final totalPages = _pageCount(_filteredItems.length);
    final nextPage = page.clamp(1, totalPages);
    if (nextPage == _currentPage) {
      return;
    }
    setState(() {
      _currentPage = nextPage;
    });
  }

  void _onRegionSelected(String? region) {
    final normalized = region?.trim();
    final filtered = _filterJobs(
      widget.feed.items,
      regionFilter: normalized?.isEmpty ?? true ? null : normalized,
    );
    final totalPages = _pageCount(filtered.length);

    setState(() {
      _selectedRegion = normalized?.isEmpty ?? true ? null : normalized;
      _filteredItems = filtered;
      _currentPage = math.min(1, totalPages);
    });
  }

  void _onCategorySelected(String? category) {
    final normalized = category?.trim();
    final filtered = _filterJobs(
      widget.feed.items,
      categoryFilter: normalized?.isEmpty ?? true ? null : normalized,
    );
    final totalPages = _pageCount(filtered.length);

    setState(() {
      _selectedCategory = normalized?.isEmpty ?? true ? null : normalized;
      _filteredItems = filtered;
      _currentPage = math.min(1, totalPages);
    });
  }

  void _onSearchChanged(String value) {
    final query = value.trim();
    final filtered = _filterJobs(
      widget.feed.items,
      searchFilter: query,
    );
    final totalPages = _pageCount(filtered.length);

    setState(() {
      _searchQuery = query;
      _filteredItems = filtered;
      _currentPage = math.min(1, totalPages);
    });
  }

  void _clearSearch() {
    if (_searchController.text.isEmpty) {
      return;
    }
    _searchController.clear();
    _onSearchChanged('');
  }
  void _toggleCategoryVisibility() {
    if (_availableCategories.isEmpty) {
      return;
    }
    setState(() {
      _showCategories = !_showCategories;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = _pageCount(_filteredItems.length);
    final currentPage = _currentPage.clamp(1, totalPages);
    final jobs = _visibleJobs(currentPage);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
      children: [
        _Header(totalCount: widget.feed.totalCount),
        const SizedBox(height: 24),
        _FilterPanel(
          regions: _availableRegions,
          selectedRegion: _selectedRegion,
          onRegionSelected: _onRegionSelected,
          searchController: _searchController,
          onSearchChanged: _onSearchChanged,
          onSearchCleared: _clearSearch,
        ),
        const SizedBox(height: 16),
        Text(
          '총 ${_filteredItems.length}건의 공고가 검색되었습니다.',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.subtext,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (_availableCategories.isNotEmpty) ...[
          const SizedBox(height: 16),
          _CategorySelector(
            categories: _availableCategories,
            selectedCategory: _selectedCategory,
            onSelected: _onCategorySelected,
            expanded: _showCategories,
            onToggle: _toggleCategoryVisibility,
          ),
        ],
        const SizedBox(height: 24),
        _JobsGrid(jobs: jobs),
        const SizedBox(height: 32),
        _PaginationControls(
          currentPage: currentPage,
          totalPages: totalPages,
          onPageSelected: _onPageSelected,
        ),
      ],
    );
  }

  int _pageCount(int itemCount) {
    if (itemCount <= 0) {
      return 1;
    }
    return ((itemCount - 1) / _pageSize).floor() + 1;
  }

  List<JobPosting> _visibleJobs(int page) {
    final startIndex = (page - 1) * _pageSize;
    return _filteredItems
        .skip(startIndex)
        .take(_pageSize)
        .toList(growable: false);
  }

  List<JobPosting> _filterJobs(
    List<JobPosting> items, {
    String? regionFilter,
    String? categoryFilter,
    String? searchFilter,
  }) {
    final region = regionFilter ?? _selectedRegion;
    final category = categoryFilter ?? _selectedCategory;
    final trimmedQuery = (searchFilter ?? _searchQuery).trim().toLowerCase();

    return items.where((job) {
      if (region != null && region.isNotEmpty) {
        final regions = _splitMultiValue(job.region);
        if (regions.isEmpty) {
          if (!job.region.toLowerCase().contains(region.toLowerCase())) {
            return false;
          }
        } else if (!regions.contains(region)) {
          return false;
        }
      }

      if (category != null && category.isNotEmpty) {
        if (job.occupations.isEmpty || !job.occupations.contains(category)) {
          return false;
        }
      }

      if (trimmedQuery.isNotEmpty) {
        if (!job.title.toLowerCase().contains(trimmedQuery) &&
            !job.company.toLowerCase().contains(trimmedQuery) &&
            !job.region.toLowerCase().contains(trimmedQuery)) {
          return false;
        }
      }

      return true;
    }).toList(growable: false);
  }

  List<String> _collectRegions(List<JobPosting> items) {
    final seen = <String>{};
    final regions = <String>[];
    for (final job in items) {
      final parts = _splitMultiValue(job.region);
      if (parts.isEmpty) {
        final trimmed = job.region.trim();
        if (trimmed.isNotEmpty && seen.add(trimmed)) {
          regions.add(trimmed);
        }
      } else {
        for (final part in parts) {
          if (seen.add(part)) {
            regions.add(part);
          }
        }
      }
    }
    regions.sort();
    return regions;
  }

  List<String> _collectCategories(List<JobPosting> items) {
    final seen = <String>{};
    final categories = <String>[];
    for (final job in items) {
      for (final occupation in job.occupations) {
        final trimmed = occupation.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        if (seen.add(trimmed)) {
          categories.add(trimmed);
        }
      }
    }
    categories.sort();
    return categories;
  }

  List<String> _splitMultiValue(String? source) {
    if (source == null) {
      return const <String>[];
    }
    final text = source.trim();
    if (text.isEmpty) {
      return const <String>[];
    }

    final parts = text.split(RegExp(r'[\n/,·ㆍ]'));
    final seen = <String>{};
    final values = <String>[];
    for (final part in parts) {
      final normalized = part.trim();
      if (normalized.isEmpty) {
        continue;
      }
      if (seen.add(normalized)) {
        values.add(normalized);
      }
    }
    return values;
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
          children: const [
            CircleAvatar(
              radius: 18,
              backgroundImage: AssetImage('assets/logo.png'),
              backgroundColor: Colors.transparent,
            ),
            SizedBox(width: 8),
            Text(
              'Ai',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: 4),
            Text(
              '채용공고',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          '채용정보 총 $totalCount건',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '데이터 출처: 공공데이터포털(기획재정부 공공기관 채용정보 조회서비스)',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.subtext,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.regions,
    required this.selectedRegion,
    required this.onRegionSelected,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchCleared,
  });

  final List<String> regions;
  final String? selectedRegion;
  final ValueChanged<String?> onRegionSelected;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 560;
            final regionTile = _buildRegionTile(context);
            final searchTile = _buildSearchTile();

            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  regionTile,
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFE1E1E5)),
                  const SizedBox(height: 16),
                  searchTile,
                ],
              );
            }

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: regionTile),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(
                      width: 1,
                      color: const Color(0xFFE1E1E5),
                    ),
                  ),
                  Expanded(flex: 2, child: searchTile),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRegionTile(BuildContext context) {
    final displayLabel = selectedRegion ?? '전체 지역';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: regions.isEmpty ? null : () => _showRegionSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 20, color: AppColors.text),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '지역 선택',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      displayLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.keyboard_arrow_down, color: AppColors.subtext),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchTile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: const [
            Icon(Icons.search, size: 20, color: AppColors.text),
            SizedBox(width: 8),
            Text(
              '검색어 입력',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: searchController,
          builder: (context, value, _) {
            return DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE1E1E5)),
              ),
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                onSubmitted: onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: '검색어를 입력하세요',
                  hintStyle: const TextStyle(color: AppColors.subtext),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: onSearchCleared,
                          splashRadius: 18,
                          icon: const Icon(Icons.clear, size: 18),
                          tooltip: '검색어 지우기',
                        ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _showRegionSheet(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => _SelectionSheet(
        title: '지역 선택',
        options: regions,
        selectedValue: selectedRegion,
      ),
    );

    if (selected == null) {
      return;
    }

    if (selected.isEmpty) {
      onRegionSelected(null);
    } else {
      onRegionSelected(selected);
    }
  }
}

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
    required this.expanded,
    required this.onToggle,
  });

  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String?> onSelected;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedLabel =
        (selectedCategory == null || selectedCategory!.isEmpty)
            ? '전체'
            : selectedCategory!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  const Text(
                    '직업 카테고리',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      selectedLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.subtext,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.subtext,
                  ),
                ],
              ),
              ),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const minTileWidth = 140.0;
              const tileHeight = 48.0;
              const spacing = 12.0;

              final crossAxisCount = math.max(
                1,
                (constraints.maxWidth / minTileWidth).floor(),
              );
              final horizontalSpacing = spacing * (crossAxisCount - 1);
              final widthPerTile =
                  (constraints.maxWidth - horizontalSpacing) / crossAxisCount;
              final childAspectRatio = widthPerTile / tileHeight;

              final options = <_CategoryOption>[
                const _CategoryOption(label: '전체', value: null),
                ...categories.map(
                  (category) =>
                      _CategoryOption(label: category, value: category),
                ),
              ];

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                  childAspectRatio: childAspectRatio,
                ),
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  final isSelected = option.value == null
                      ? selectedCategory == null
                      : selectedCategory == option.value;
                  return _CategoryTile(
                    label: option.label,
                    selected: isSelected,
                    onTap: () {
                      if (isSelected) {
                        onSelected(null);
                      } else {
                        onSelected(option.value);
                      }
                    },
                  );
                },
              );
            },
          ),
        ],
      ],
    );
  }
}

class _CategoryOption {
  const _CategoryOption({required this.label, required this.value});

  final String label;
  final String? value;
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected
                ? AppColors.mint.withOpacity(0.15)
                : Colors.white,
            border: Border.all(
              color: selected ? AppColors.mint : const Color(0xFFE1E1E5),
              width: 1.1,
            ),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: selected ? AppColors.text : AppColors.subtext,
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionSheet extends StatelessWidget {
  const _SelectionSheet({
    required this.title,
    required this.options,
    required this.selectedValue,
  });

  final String title;
  final List<String> options;
  final String? selectedValue;

  @override
  Widget build(BuildContext context) {
    final height = math.min(
      MediaQuery.of(context).size.height * 0.6,
      72.0 * (options.length + 1) + 96,
    );

    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: options.length + 1,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    final isSelected = selectedValue == null;
                    return ListTile(
                      title: const Text('전체 지역'),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: AppColors.mint)
                          : null,
                      onTap: () => Navigator.of(context).pop(''),
                    );
                  }

                  final option = options[index - 1];
                  final isSelected = option == selectedValue;
                  return ListTile(
                    title: Text(option),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: AppColors.mint)
                        : null,
                    onTap: () => Navigator.of(context).pop(option),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobsGrid extends StatelessWidget {
  const _JobsGrid({required this.jobs});

  final List<JobPosting> jobs;

  static const _palette = <Color>[
    Color(0xFF6C63FF),
    Color(0xFF4F86FF),
    Color(0xFF2CB1A3),
    Color(0xFFFF7043),
    Color(0xFF8E24AA),
    Color(0xFF43A047),
  ];

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text(
            '해당 페이지에 표시할 공고가 없습니다.',
            style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.subtext) ??
                const TextStyle(color: AppColors.subtext),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const spacing = 16.0;
        final crossAxisCount = width >= 900
            ? 3
            : width >= 640
                ? 2
                : 1;
        final itemWidth = crossAxisCount == 1
            ? width
            : (width - spacing * (crossAxisCount - 1)) / crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var i = 0; i < jobs.length; i++)
              SizedBox(
                width: crossAxisCount == 1 ? width : itemWidth,
                child: _JobCard(
                  job: jobs[i],
                  color: _palette[i % _palette.length],
                ),
              ),
          ],
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
    final meta = _buildMeta(job);
    final secondaryStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.subtext,
            ) ??
        const TextStyle(color: AppColors.subtext);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => JobDetailPage(job: job)),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.companyLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      job.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      meta,
                      style: secondaryStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right, color: AppColors.subtext),
            ],
          ),
        ),
      ),
    );
  }

  String _buildMeta(JobPosting job) {
    final parts = <String>[];
    final region = job.regionLabel.trim();
    if (region.isNotEmpty) {
      parts.add(region);
    }
    if (job.tags.isNotEmpty) {
      parts.add(job.tags.first);
    } else {
      final date = job.prettyPostedDate;
      if (date != null && date.isNotEmpty) {
        parts.add(date);
      }
    }
    if (parts.isEmpty) {
      return '상세 정보 확인';
    }
    return parts.join(' · ');
  }
}

class _PaginationControls extends StatelessWidget {
  const _PaginationControls({
    required this.currentPage,
    required this.totalPages,
    required this.onPageSelected,
  });

  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageSelected;

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) {
      return const SizedBox.shrink();
    }

    final pages = _visiblePages();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ArrowButton(
          icon: Icons.chevron_left,
          onPressed:
              currentPage > 1 ? () => onPageSelected(currentPage - 1) : null,
        ),
        const SizedBox(width: 12),
        for (final page in pages)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _PageButton(
              page: page,
              isActive: page == currentPage,
              onTap: () => onPageSelected(page),
            ),
          ),
        const SizedBox(width: 12),
        _ArrowButton(
          icon: Icons.chevron_right,
          onPressed: currentPage < totalPages
              ? () => onPageSelected(currentPage + 1)
              : null,
        ),
      ],
    );
  }

  List<int> _visiblePages() {
    const window = 5;
    if (totalPages <= window) {
      return [for (var i = 1; i <= totalPages; i++) i];
    }
    final block = ((currentPage - 1) / window).floor();
    final start = block * window + 1;
    final end = math.min(start + window - 1, totalPages);
    return [for (var i = start; i <= end; i++) i];
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.page,
    required this.isActive,
    required this.onTap,
  });

  final int page;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = isActive ? AppColors.mint : Colors.white;
    final foreground = isActive ? Colors.black : AppColors.subtext;
    final borderColor = isActive ? AppColors.mint : const Color(0xFFE1E1E5);

    return SizedBox(
      width: 44,
      height: 40,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          side: BorderSide(color: borderColor),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ) ??
              const TextStyle(fontWeight: FontWeight.w700),
        ),
        child: Text('$page'),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final background = enabled ? Colors.white : const Color(0xFFE9E9EC);
    final iconColor = enabled ? AppColors.text : AppColors.subtext;

    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(20),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor),
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.only(top: 120),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 160),
      children: const [
        Icon(Icons.work_outline, size: 48, color: AppColors.subtext),
        SizedBox(height: 12),
        const Center(
          child: Text(
            '조회된 채용공고가 없습니다.',
            style: TextStyle(color: AppColors.subtext),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 160),
      children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
        const SizedBox(height: 12),
        Center(
          child: Text(
            '채용공고를 불러오지 못했습니다.\n${error ?? ''}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.subtext),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('다시 시도'),
          ),
        ),
      ],
    );
  }
}
