import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/system_state.dart';
import '../../../core/widgets/team_crest.dart';
import '../data/search_repository.dart';

/// Màn 29 · Tìm kiếm chung: đội, sân, kèo, cầu thủ.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

const _tabs = <(SearchFindTypeValue, String)>[
  (SearchFindTypeValue.all, 'Tất cả'),
  (SearchFindTypeValue.teams, 'Đội'),
  (SearchFindTypeValue.pitches, 'Sân'),
  (SearchFindTypeValue.posts, 'Kèo'),
  (SearchFindTypeValue.players, 'Cầu thủ'),
];

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  String _q = '';
  SearchFindTypeValue _type = SearchFindTypeValue.all;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _q = v.trim());
    });
  }

  void _run(String q) {
    _ctrl.text = q;
    _ctrl.selection = TextSelection.collapsed(offset: q.length);
    setState(() => _q = q.trim());
  }

  void _open(SearchItemDto it) {
    ref.read(recentSearchesProvider.notifier).add(_q);
    final kind = (it.kind is SearchItemDtoKindKnown) ? (it.kind as SearchItemDtoKindKnown).value : null;
    final path = switch (kind) {
      SearchItemDtoKindValue.teams => '/team-profile/${it.id}',
      SearchItemDtoKindValue.pitches => '/pitch/${it.id}',
      SearchItemDtoKindValue.posts => '/posts/${it.id}',
      SearchItemDtoKindValue.players => '/players/${it.id}',
      null => null,
    };
    if (path != null) context.push(path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(AppRadius.button),
                        border: Border.all(color: AppColors.lineStrong),
                      ),
                      child: Row(
                        children: [
                          const AppIcon(AppIcons.search, size: 20, color: AppColors.textDim),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _ctrl,
                              autofocus: true,
                              textInputAction: TextInputAction.search,
                              onChanged: _onChanged,
                              onSubmitted: (v) => setState(() => _q = v.trim()),
                              style: const TextStyle(fontSize: 15, color: AppColors.textMain),
                              decoration: const InputDecoration(
                                hintText: 'Tìm kiếm đội, sân, kèo, cầu thủ',
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                isDense: true,
                              ),
                            ),
                          ),
                          if (_ctrl.text.isNotEmpty)
                            Semantics(
                              button: true,
                              label: 'Xoá từ khoá',
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _ctrl.clear();
                                  _q = '';
                                }),
                                child: const AppIcon(AppIcons.close, size: 18, color: AppColors.textDim),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  LinkButton('Huỷ', onTap: () => context.pop(), color: AppColors.lime),
                ],
              ),
            ),
            Expanded(child: _q.isEmpty ? _idle() : _results()),
          ],
        ),
      ),
    );
  }

  Widget _idle() {
    final recents = ref.watch(recentSearchesProvider);
    final trending = ref.watch(trendingSearchProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (recents.isNotEmpty) ...[
          Row(
            children: [
              const Expanded(child: Text('TÌM GẦN ĐÂY', style: AppText.label)),
              LinkButton(
                'Xoá',
                onTap: () => ref.read(recentSearchesProvider.notifier).clear(),
                color: AppColors.textDim,
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final r in recents) _Chip(label: r, onTap: () => _run(r))],
          ),
          const SizedBox(height: 24),
        ],
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text('ĐANG HOT QUANH BẠN', style: AppText.label),
        ),
        AsyncView(
          value: trending,
          onRetry: () => ref.invalidate(trendingSearchProvider),
          data: (items) => items.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Chưa có gợi ý nào quanh bạn.',
                    style: TextStyle(fontSize: 14, color: AppColors.textDim),
                  ),
                )
              : Column(
                  children: [
                    for (final (i, t) in items.indexed)
                      _TrendingRow(rank: i + 1, label: t.label, onTap: () => _run(t.query)),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _results() {
    final res = ref.watch(searchResultsProvider((q: _q, type: _type)));
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: [
              for (final t in _tabs)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Chip(
                    label: t.$2 +
                        (t.$1 == SearchFindTypeValue.all
                            ? ''
                            : _countOf(res.value, t.$1)),
                    selected: _type == t.$1,
                    onTap: () => setState(() => _type = t.$1),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: AsyncView(
            value: res,
            onRetry: () => ref.invalidate(searchResultsProvider),
            data: (r) {
              final groups = r.groups.where((g) => g.items.isNotEmpty).toList();
              if (groups.isEmpty) {
                return Center(
                  child: EmptyState(
                    title: 'Không thấy “$_q”',
                    message: 'Thử tên đội, tên sân hoặc khu vực khác.',
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  for (final g in groups) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
                      child: Text(
                        '${_groupLabel(g.kind).toUpperCase()} · ${g.count}',
                        style: AppText.label,
                      ),
                    ),
                    for (final it in g.items) _ResultRow(item: it, onTap: () => _open(it)),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  String _countOf(SearchResponseDto? r, SearchFindTypeValue t) {
    if (r == null) return '';
    for (final g in r.groups) {
      if (g.kind is SearchGroupDtoKindKnown && (g.kind as SearchGroupDtoKindKnown).value.value == t.value) {
        return ' ${g.count}';
      }
    }
    return '';
  }

  String _groupLabel(SearchGroupDtoKind k) => switch (k) {
    SearchGroupDtoKindKnown(value: SearchGroupDtoKindValue.teams) => 'Đội',
    SearchGroupDtoKindKnown(value: SearchGroupDtoKindValue.pitches) => 'Sân',
    SearchGroupDtoKindKnown(value: SearchGroupDtoKindValue.posts) => 'Kèo',
    SearchGroupDtoKindKnown(value: SearchGroupDtoKindValue.players) => 'Cầu thủ',
    _ => 'Khác',
  };
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap, this.selected = false});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.lime : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: selected ? AppColors.lime : AppColors.lineStrong),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.ink : AppColors.textBody,
          ),
        ),
      ),
    ),
  );
}

class _TrendingRow extends StatelessWidget {
  const _TrendingRow({required this.rank, required this.label, required this.onTap});
  final int rank;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Row(
        children: [
          SizedBox(width: 32, child: Text('$rank', style: AppText.display(24, color: AppColors.lime))),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, color: AppColors.textMain),
            ),
          ),
          const AppIcon(AppIcons.chevronRight, size: 18, color: AppColors.textDim),
        ],
      ),
    ),
  );
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.item, required this.onTap});
  final SearchItemDto item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isTeam =
        item.kind is SearchItemDtoKindKnown &&
        (item.kind as SearchItemDtoKindKnown).value == SearchItemDtoKindValue.teams;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.group),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              if (isTeam)
                SizedBox(
                  width: 44,
                  child: Center(child: TeamCrest(name: item.title, color: '#2F7BFF', width: 36)),
                )
              else
                Avatar(name: item.title, url: item.imageUrl, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMain,
                      ),
                    ),
                    if (item.subtitle != null)
                      Text(
                        item.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppColors.textDim),
                      ),
                  ],
                ),
              ),
              const AppIcon(AppIcons.chevronRight, size: 18, color: AppColors.textDim),
            ],
          ),
        ),
      ),
    );
  }
}
