import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../team/team_providers.dart';
import '../data/funds_repository.dart';
import 'fund_widgets.dart';

/// Toàn bộ giao dịch quỹ, tải thêm theo trang.
class FundTransactionsScreen extends ConsumerStatefulWidget {
  const FundTransactionsScreen({super.key});

  @override
  ConsumerState<FundTransactionsScreen> createState() => _FundTransactionsScreenState();
}

class _FundTransactionsScreenState extends ConsumerState<FundTransactionsScreen> {
  final List<FundTxDto> _items = [];
  String? _cursor;
  bool _loading = false;
  bool _done = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadMore);
  }

  Future<void> _reload() async {
    setState(() {
      _items.clear();
      _cursor = null;
      _done = false;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    final teamId = ref.read(currentTeamIdProvider);
    if (teamId == null || _loading || _done) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref.read(fundsRepositoryProvider).transactions(teamId, cursor: _cursor);
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _done = page.nextCursor == null;
      });
    } catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamId = ref.watch(currentTeamIdProvider);
    if (teamId == null) return const Scaffold();
    final canManage = ref.watch(teamDetailProvider(teamId)).value?.myRole.canManageFunds ?? false;
    // Có khoản mới / bị xoá (realtime hoặc từ màn khác) → tải lại từ đầu
    ref.listen(fundSummaryProvider(teamId), (prev, next) {
      if (prev?.value != null && next.hasValue) _reload();
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: const Color(0x00000000),
        title: Text('GIAO DỊCH QUỸ', style: AppText.display(24)),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.extentAfter < 300) _loadMore();
            return false;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (_items.isNotEmpty)
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      for (final (i, t) in _items.indexed) ...[
                        if (i > 0) const Divider(height: 1, color: AppColors.divider),
                        FundTxRow(teamId: teamId, tx: t, canManage: canManage),
                      ],
                    ],
                  ),
                ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              if (_error != null)
                AsyncView<void>(
                  value: AsyncError(_error!, StackTrace.empty),
                  data: (_) => const SizedBox(),
                  onRetry: _loadMore,
                ),
              if (_done && _items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Chưa có giao dịch', textAlign: TextAlign.center),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
