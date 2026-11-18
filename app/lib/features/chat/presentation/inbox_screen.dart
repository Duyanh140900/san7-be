import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/format.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/pills.dart';
import '../../../core/widgets/system_state.dart';
import '../../../core/widgets/team_crest.dart';
import '../data/chat_repository.dart';

/// Màn 26 · Danh sách tin nhắn / Hộp thư.
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  int _tabIndex = 0; // 0: Tất cả, 1: Chưa đọc

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inboxAsync = ref.watch(inboxProvider);

    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(
                children: [
                  SquareIconButton(
                    tooltip: 'Quay lại',
                    onPressed: () => context.canPop() ? context.pop() : context.go(Routes.feed),
                    child: const AppIcon(AppIcons.back, size: 22, color: AppColors.textMain),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tin nhắn',
                      style: AppText.display(28, color: AppColors.textMain),
                    ),
                  ),
                  if (inboxAsync.value?.unreadTotal case final unread? when unread > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.lime,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '$unread chưa đọc',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(inboxProvider.future),
                child: AsyncView(
                  value: inboxAsync,
                  onRetry: () => ref.invalidate(inboxProvider),
                  data: (inbox) {
                    final items = inbox.items.where((c) {
                      if (_tabIndex == 1 && c.unreadCount == 0) return false;
                      if (_query.isNotEmpty &&
                          !c.teamName.toLowerCase().contains(_query.toLowerCase())) {
                        return false;
                      }
                      return true;
                    }).toList();

                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                      children: [
                        // Search bar
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(AppRadius.button),
                            border: Border.all(color: AppColors.line),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            children: [
                              const AppIcon(AppIcons.search, size: 20, color: AppColors.textDim),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (val) => setState(() => _query = val.trim()),
                                  style: const TextStyle(fontSize: 15, color: AppColors.textMain),
                                  decoration: InputDecoration(
                                    hintText: 'Tìm đội, cuộc trò chuyện...',
                                    hintStyle: const TextStyle(color: AppColors.textDim),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                    suffixIcon: _query.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 18),
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() => _query = '');
                                            },
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Đang hoạt động / Hoạt động gần đây
                        if (inbox.items.isNotEmpty) ...[
                          Text('ĐANG HOẠT ĐỘNG', style: AppText.label),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 72,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: inbox.items.length,
                              separatorBuilder: (_, _) => const SizedBox(width: 12),
                              itemBuilder: (ctx, idx) {
                                final c = inbox.items[idx];
                                return InkWell(
                                  onTap: () => context.push(Routes.chat(c.teamId, c.matchId)),
                                  borderRadius: BorderRadius.circular(AppRadius.tile),
                                  child: Column(
                                    children: [
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          TeamCrest(name: c.teamName, color: c.crestColor, width: 44),
                                          Positioned(
                                            right: 0,
                                            bottom: 0,
                                            child: Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                color: AppColors.lime,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: AppColors.night, width: 2),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      SizedBox(
                                        width: 58,
                                        child: Text(
                                          c.teamName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textBody,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Tabs: Tất cả, Chưa đọc
                        Row(
                          children: [
                            FilterPill(
                              label: 'Tất cả (${inbox.items.length})',
                              selected: _tabIndex == 0,
                              onTap: () => setState(() => _tabIndex = 0),
                            ),
                            const SizedBox(width: 8),
                            FilterPill(
                              label: 'Chưa đọc (${inbox.unreadTotal})',
                              selected: _tabIndex == 1,
                              onTap: () => setState(() => _tabIndex = 1),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Thread list
                        if (items.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: EmptyState(
                              title: 'Chưa có cuộc trò chuyện',
                              message: _query.isNotEmpty
                                  ? 'Không tìm thấy kết quả phù hợp'
                                  : 'Nhắn cho đội đối từ một kèo để bắt đầu.',
                              compact: true,
                            ),
                          )
                        else
                          for (final c in items) ...[
                            _ConversationTile(
                              item: c,
                              onTap: () => context.push(Routes.chat(c.teamId, c.matchId)),
                            ),
                            const SizedBox(height: 8),
                          ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.item, required this.onTap});
  final InboxConversationDto item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = item.unreadCount > 0;
    final lastMsg = item.lastMessage?.body ?? 'Chưa có tin nhắn';
    final timeStr = Fmt.ago(item.updatedAt);

    return Material(
      color: unread ? AppColors.primaryTint : AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              TeamCrest(name: item.teamName, color: item.crestColor, width: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.teamName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                              color: AppColors.textMain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 12,
                            color: unread ? AppColors.lime : AppColors.textDim,
                            fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMsg,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: unread ? AppColors.textMain : AppColors.textDim,
                              fontWeight: unread ? FontWeight.w500 : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.lime,
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              '${item.unreadCount}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
