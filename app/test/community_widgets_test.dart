import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:san7/api/san7_api.dart';
import 'package:san7/features/posts/data/posts_repository.dart';
import 'package:san7/features/posts/presentation/community_widgets.dart';
import 'package:san7/features/posts/posts_providers.dart';

void main() {
  const postId = 'post-1';
  final reactions = ReactionPageDto(
    counts: const [
      ReactionCountDto(kind: ReactionKind.like, count: 2),
      ReactionCountDto(kind: ReactionKind.love, count: 1),
      ReactionCountDto(kind: ReactionKind.fire, count: 0),
      ReactionCountDto(kind: ReactionKind.haha, count: 0),
      ReactionCountDto(kind: ReactionKind.sad, count: 0),
    ],
    myKind: ReactionKind.like,
    items: const [],
  );

  Widget subject() => ProviderScope(
    overrides: [
      postReactionsProvider(postId).overrideWithValue(AsyncData(reactions)),
      postsRepositoryProvider.overrideWithValue(_FakePostsRepository()),
    ],
    child: const MaterialApp(
      home: Scaffold(body: PostCommunityBar(postId: postId)),
    ),
  );

  test('đủ năm nhãn và emoji cảm xúc', () {
    expect(reactionEmoji(ReactionKind.like), '👍');
    expect(reactionEmoji(ReactionKind.love), '❤️');
    expect(reactionEmoji(ReactionKind.fire), '🔥');
    expect(reactionEmoji(ReactionKind.haha), '😂');
    expect(reactionEmoji(ReactionKind.sad), '😢');
    expect(reactionLabel(ReactionKindValue.like), 'Thích');
    expect(reactionLabel(ReactionKindValue.sad), 'Buồn');
  });

  testWidgets('thanh cảm xúc hiển thị số đếm và mở đủ năm lựa chọn', (
    tester,
  ) async {
    await tester.pumpWidget(subject());

    expect(find.text('3'), findsOneWidget);
    expect(find.text('Đã bày tỏ'), findsOneWidget);
    await tester.tap(find.text('Đã bày tỏ'));
    await tester.pumpAndSettle();

    expect(find.text('👍'), findsNWidgets(3));
    expect(find.text('❤️'), findsNWidgets(2));
    expect(find.text('🔥'), findsOneWidget);
    expect(find.text('😂'), findsOneWidget);
    expect(find.text('😢'), findsOneWidget);
  });

  testWidgets('mở sheet bình luận có ô nhập và nút gửi', (tester) async {
    await tester.pumpWidget(subject());

    await tester.tap(find.text('Bình luận').first);
    await tester.pump();

    expect(find.text('Bình luận'), findsNWidgets(2));
    expect(find.byKey(const Key('comment-input')), findsOneWidget);
    expect(find.byKey(const Key('comment-send')), findsOneWidget);
  });
}

class _FakePostsRepository extends PostsRepository {
  _FakePostsRepository() : super(San7Api(Dio()), Dio());

  @override
  Future<CommentPageDto> comments(String postId, {String? cursor}) async =>
      const CommentPageDto(items: []);
}
