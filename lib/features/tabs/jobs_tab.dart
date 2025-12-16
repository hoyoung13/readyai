import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../jobs/job_categories.dart';
import '../jobs/job_detail_page.dart';
import '../jobs/job_posting.dart';
import '../jobs/job_posting_loader.dart';
import '../jobs/job_posting_service.dart';
import 'tabs_shared.dart';

class JobsTab extends StatefulWidget {
  const JobsTab({super.key});
  @override
  State<JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends State<JobsTab> {
  late Future<JobFeed> _future;
  final JobPostingService _postingService = JobPostingService();

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<JobFeed> _fetch() async {
    try {
      final companyPosts = await _postingService.fetchPublicPosts();
      final approved = companyPosts
          .map((post) => post.toJobPosting())
          .where((job) => job.visible)
          .toList(growable: false);
      return JobFeed(items: approved);
    } catch (_) {
      return const JobFeed(items: <JobPosting>[]);
    }
  }

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
  Map<String, Map<String, List<String>>> _regionTree =
      const <String, Map<String, List<String>>>{};
  List<String> _standardRegions = const <String>[];
  List<String> _availableRegions = const <String>[];
  Map<String, List<String>> _categoryTree = const <String, List<String>>{};
  List<String> _standardCategories = const <String>[];
  List<String> _availableCategories = const <String>[];
  List<JobPosting> _filteredItems = const <JobPosting>[];
  bool _showCategories = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _refreshFiltersFrom(widget.feed.items);
    _loadRegionData();
    _loadCategoryData();
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
      _refreshFiltersFrom(widget.feed.items);
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
      categoryFilter: _selectedCategory,
      searchFilter: _searchQuery,
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
      regionFilter: _selectedRegion,
      categoryFilter: normalized?.isEmpty ?? true ? null : normalized,
      searchFilter: _searchQuery,
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
      regionFilter: _selectedRegion,
      categoryFilter: _selectedCategory,
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
          regionTree: _regionTree,
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
          HierarchicalCategorySelector(
            categoryTree: _categoryTree,
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
      if (!job.visible) {
        return false;
      }
      if (region != null && region.isNotEmpty) {
        final regionText =
            (job.regionLabel.isNotEmpty ? job.regionLabel : job.region)
                .toLowerCase();
        if (!regionText.contains(region.toLowerCase())) {
          return false;
        }
      }

      if (category != null && category.isNotEmpty) {
        final normalized = category.toLowerCase();
        final lastSegment = category.split('>').last.trim().toLowerCase();
        final hasCategory = job.occupations.any((occupation) {
          final value = occupation.toLowerCase();
          return value.contains(normalized) || value.contains(lastSegment);
        });
        if (!hasCategory) {
          return false;
        }
      }

      if (trimmedQuery.isNotEmpty) {
        if (!job.title.toLowerCase().contains(trimmedQuery) &&
            !job.company.toLowerCase().contains(trimmedQuery) &&
            !job.regionLabel.toLowerCase().contains(trimmedQuery)) {
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

  Future<void> _loadRegionData() async {
    try {
      final text = await rootBundle.loadString('assets/regions.json');
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        final parsedTree = _parseRegionTree(decoded);
        final flattened = _flattenRegionTree(parsedTree);
        if (flattened.isNotEmpty) {
          _regionTree = parsedTree;
          _standardRegions = flattened;
          _refreshFiltersFrom(widget.feed.items, regions: flattened);
          return;
        }
      }
    } catch (_) {
      // Ignore and fall back to collected regions.
    }

    _refreshFiltersFrom(widget.feed.items);
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

  Future<void> _loadCategoryData() async {
    _categoryTree = _normalizeCategoryTree(subCategoryMap);
    final flattened = _flattenCategoryTree(_categoryTree);
    if (flattened.isNotEmpty) {
      _standardCategories = flattened;
      _refreshFiltersFrom(widget.feed.items, categories: flattened);
      return;
    }

    _refreshFiltersFrom(widget.feed.items);
  }

  void _refreshFiltersFrom(
    List<JobPosting> items, {
    List<String>? regions,
    List<String>? categories,
  }) {
    if (!mounted) {
      return;
    }
    final resolvedRegions = regions ?? _resolveRegions(items);
    final resolvedCategories = categories ?? _resolveCategories(items);

    final nextRegion =
        _selectedRegion != null && resolvedRegions.contains(_selectedRegion!)
            ? _selectedRegion
            : null;
    final nextCategory = _selectedCategory != null &&
            resolvedCategories.contains(_selectedCategory!)
        ? _selectedCategory
        : null;

    final filtered = _filterJobs(
      items,
      regionFilter: nextRegion,
      categoryFilter: nextCategory,
    );
    final totalPages = _pageCount(filtered.length);

    setState(() {
      _availableRegions = resolvedRegions;
      _availableCategories = resolvedCategories;
      _selectedRegion = nextRegion;
      _selectedCategory = nextCategory;
      _filteredItems = filtered;
      _currentPage = math.min(_currentPage, totalPages);
    });
  }

  List<String> _resolveRegions(List<JobPosting> items) {
    if (_standardRegions.isNotEmpty) {
      return _standardRegions;
    }
    return _collectRegions(items);
  }

  List<String> _resolveCategories(List<JobPosting> items) {
    if (_standardCategories.isNotEmpty) {
      return _standardCategories;
    }
    return _collectCategories(items);
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

  Map<String, Map<String, List<String>>> _parseRegionTree(
    Map<String, dynamic> data,
  ) {
    final result = <String, Map<String, List<String>>>{};

    data.forEach((cityKey, districtValue) {
      final city = cityKey.toString().trim();
      if (city.isEmpty) {
        return;
      }

      final districts = <String, List<String>>{};
      if (districtValue is Map<String, dynamic>) {
        districtValue.forEach((districtKey, neighborhoodsValue) {
          final district = districtKey.toString().trim();
          if (district.isEmpty) {
            return;
          }

          if (neighborhoodsValue is List) {
            final neighborhoods = neighborhoodsValue
                .map((n) => n?.toString().trim())
                .whereType<String>()
                .where((value) => value.isNotEmpty)
                .toList();
            districts[district] = neighborhoods;
          } else {
            districts[district] = const <String>[];
          }
        });
      }
      result[city] = districts;
    });

    return result;
  }

  List<String> _flattenRegionTree(
    Map<String, Map<String, List<String>>> tree,
  ) {
    final seen = <String>{};
    final regions = <String>[];

    tree.forEach((city, districts) {
      if (seen.add(city)) {
        regions.add(city);
      }

      districts.forEach((district, neighborhoods) {
        final districtLabel = '$city $district';
        if (seen.add(districtLabel)) {
          regions.add(districtLabel);
        }

        for (final neighborhood in neighborhoods) {
          final neighborhoodLabel = '$districtLabel $neighborhood';
          if (seen.add(neighborhoodLabel)) {
            regions.add(neighborhoodLabel);
          }
        }
      });
    });

    regions.sort();
    return regions;
  }

  Map<String, List<String>> _normalizeCategoryTree(
    Map<String, List<String>> source,
  ) {
    final normalized = <String, List<String>>{};

    source.forEach((main, subs) {
      final mainLabel = main.trim();
      if (mainLabel.isEmpty) {
        return;
      }

      final uniqueSubs = <String>{};
      final cleanedSubs = <String>[];
      for (final sub in subs) {
        final label = sub.trim();
        if (label.isEmpty || !uniqueSubs.add(label)) {
          continue;
        }
        cleanedSubs.add(label);
      }

      if (cleanedSubs.isNotEmpty) {
        normalized[mainLabel] = cleanedSubs;
      }
    });

    return normalized;
  }

  List<String> _flattenCategoryTree(Map<String, List<String>> data) {
    final seen = <String>{};
    final categories = <String>[];

    data.forEach((main, subs) {
      final mainLabel = main.trim();
      if (mainLabel.isEmpty) {
        return;
      }
      for (final sub in subs) {
        final subLabel = sub.trim();
        if (subLabel.isEmpty) {
          continue;
        }
        if (seen.add(subLabel)) {
          categories.add(subLabel);
        }
      }
    });

    categories.sort();
    return categories;
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
      ],
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.regions,
    required this.regionTree,
    required this.selectedRegion,
    required this.onRegionSelected,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchCleared,
  });

  final List<String> regions;
  final Map<String, Map<String, List<String>>> regionTree;
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
        onTap: regionTree.isEmpty ? null : () => _showRegionSheet(context),
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
      builder: (context) => RegionSelectorSheet(
        regionTree: regionTree,
        initialValue: selectedRegion,
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

class HierarchicalCategorySelector extends StatefulWidget {
  const HierarchicalCategorySelector({
    required this.categoryTree,
    required this.selectedCategory,
    required this.onSelected,
    required this.expanded,
    required this.onToggle,
  });

  final Map<String, List<String>> categoryTree;
  final String? selectedCategory;
  final ValueChanged<String?> onSelected;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  State<HierarchicalCategorySelector> createState() =>
      _HierarchicalCategorySelectorState();
}

class _HierarchicalCategorySelectorState
    extends State<HierarchicalCategorySelector> {
  late String _activeMainCategory;

  @override
  void initState() {
    super.initState();
    _activeMainCategory = _resolveInitialMain();
  }

  @override
  void didUpdateWidget(covariant HierarchicalCategorySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryTree != widget.categoryTree ||
        oldWidget.selectedCategory != widget.selectedCategory) {
      _activeMainCategory = _resolveInitialMain();
    }
  }

  String _resolveInitialMain() {
    if (widget.categoryTree.isEmpty) {
      return '';
    }

    if (widget.selectedCategory != null) {
      final entry = widget.categoryTree.entries.firstWhere(
        (entry) => entry.value.contains(widget.selectedCategory),
        orElse: () => widget.categoryTree.entries.first,
      );
      return entry.key;
    }

    return widget.categoryTree.keys.first;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.categoryTree.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedLabel =
        (widget.selectedCategory == null || widget.selectedCategory!.isEmpty)
            ? '전체'
            : widget.selectedCategory!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.list_alt, color: AppColors.text),
                  const SizedBox(width: 10),
                  const Text(
                    '직무 카테고리',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    selectedLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.subtext,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    widget.expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.subtext,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (widget.expanded) ...[
          const Divider(height: 1, color: Color(0xFFE1E1E5)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final main in widget.categoryTree.keys)
                _PillButton(
                  label: main,
                  selected: _activeMainCategory == main,
                  onTap: () {
                    setState(() {
                      _activeMainCategory = main;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            '세부 카테고리',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PillButton(
                label: '전체',
                selected: widget.selectedCategory == null,
                onTap: () => widget.onSelected(null),
              ),
              for (final sub in widget.categoryTree[_activeMainCategory] ??
                  const <String>[])
                _PillButton(
                  label: sub,
                  selected: widget.selectedCategory == sub,
                  onTap: () => widget.onSelected(sub),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
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
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.mint.withOpacity(0.14) : Colors.white,
            border: Border.all(
              color: selected ? AppColors.mint : const Color(0xFFE1E1E5),
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.text : AppColors.subtext,
            ),
          ),
        ),
      ),
    );
  }
}

class RegionSelectorSheet extends StatefulWidget {
  const RegionSelectorSheet({
    required this.regionTree,
    required this.initialValue,
  });

  final Map<String, Map<String, List<String>>> regionTree;
  final String? initialValue;

  @override
  State<RegionSelectorSheet> createState() => _RegionSelectorSheetState();
}

class _RegionSelectorSheetState extends State<RegionSelectorSheet> {
  String? _selectedCity;
  String? _selectedDistrict;
  String? _selectedNeighborhood;

  @override
  void initState() {
    super.initState();
    _applyInitialSelection();
  }

  void _applyInitialSelection() {
    final parts =
        widget.initialValue?.split(' ').where((p) => p.isNotEmpty).toList() ??
            const <String>[];

    if (parts.isEmpty) {
      return;
    }

    _selectedCity = parts.isNotEmpty ? parts.first : null;
    _selectedDistrict = parts.length > 1 ? parts[1] : null;
    _selectedNeighborhood = parts.length > 2
        ? parts.sublist(2).join(' ').trim().isEmpty
            ? null
            : parts.sublist(2).join(' ')
        : null;
  }

  String _composeSelection() {
    if (_selectedCity == null) {
      return '';
    }
    if (_selectedDistrict == null || _selectedDistrict!.isEmpty) {
      return _selectedCity!;
    }
    if (_selectedNeighborhood == null || _selectedNeighborhood!.isEmpty) {
      return '${_selectedCity!} ${_selectedDistrict!}';
    }
    return '${_selectedCity!} ${_selectedDistrict!} ${_selectedNeighborhood!}';
  }

  @override
  Widget build(BuildContext context) {
    final height = math.min(
      MediaQuery.of(context).size.height * 0.72,
      640.0,
    );

    final cities = widget.regionTree.keys.toList()..sort();
    final districts =
        widget.regionTree[_selectedCity]?.keys.toList() ?? const <String>[];
    final neighborhoods = (_selectedCity != null && _selectedDistrict != null)
        ? (widget.regionTree[_selectedCity!]?[_selectedDistrict!] ??
            const <String>[])
        : const <String>[];

    return SafeArea(
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    '지역 선택',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(''),
                    child: const Text('전체 지역'),
                  ),
                ],
              ),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _ColumnSelector(
                        title: '광역시/도',
                        options: cities,
                        selected: _selectedCity,
                        onSelected: (value) {
                          setState(() {
                            _selectedCity = value;
                            _selectedDistrict = null;
                            _selectedNeighborhood = null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ColumnSelector(
                        title: '시/군/구',
                        options: districts,
                        selected: _selectedDistrict,
                        onSelected: (value) {
                          setState(() {
                            _selectedDistrict = value;
                            _selectedNeighborhood = null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ColumnSelector(
                        title: '읍/면/동',
                        options: neighborhoods,
                        selected: _selectedNeighborhood,
                        onSelected: (value) {
                          setState(() {
                            _selectedNeighborhood = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _selectedCity = null;
                          _selectedDistrict = null;
                          _selectedNeighborhood = null;
                        });
                      },
                      child: const Text('선택 초기화'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _selectedCity == null
                          ? null
                          : () {
                              Navigator.of(context).pop(_composeSelection());
                            },
                      child: const Text('선택 완료'),
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
}

class _ColumnSelector extends StatelessWidget {
  const _ColumnSelector({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E1E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE1E1E5)),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemBuilder: (context, index) {
                final option = options[index];
                final isSelected = option == selected;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? AppColors.text
                                    : AppColors.subtext,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check,
                                color: AppColors.mint, size: 18),
                        ],
                      ),
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemCount: options.length,
            ),
          ),
        ],
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
