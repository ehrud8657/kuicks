import 'package:flutter/material.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/linkified_text.dart';

class BoardPage extends StatefulWidget {
  const BoardPage({super.key});
  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  static const filters = <(PostCategory?, String)>[
    (null, '전체'),
    (PostCategory.notice, '공지사항'),
    (PostCategory.recruit, '모집공고'),
  ];

  PostCategory? category;
  final List<Post> posts = [];
  int page = 1;
  bool hasMore = false;
  bool loading = true;
  bool loadingMore = false;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      final result = await ApiClient.instance.fetchPosts(category: category);
      if (!mounted) return;
      setState(() {
        posts
          ..clear()
          ..addAll(result.posts);
        page = 1;
        hasMore = result.hasMore;
        loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        loading = false;
        failed = true;
      });
    }
  }

  Future<void> _loadMore() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => loadingMore = true);
    try {
      final result = await ApiClient.instance.fetchPosts(
        category: category,
        page: page + 1,
      );
      if (!mounted) return;
      setState(() {
        posts.addAll(result.posts);
        page += 1;
        hasMore = result.hasMore;
        loadingMore = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() => loadingMore = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('게시글을 더 불러오지 못했습니다.')),
      );
    }
  }

  void _select(PostCategory? value) {
    if (category == value) return;
    setState(() => category = value);
    _load();
  }

  /// 선택한 분류에 맞춘 페이지 제목. 전에는 모집공고를 골라도 '공지사항'으로 고정돼 있었다.
  String get _title => switch (category) {
        PostCategory.notice => '공지사항',
        PostCategory.recruit => '모집공고',
        null => '공지사항 · 모집공고',
      };

  String get _emptyMessage => switch (category) {
        PostCategory.notice => '등록된 공지사항이 없습니다.',
        PostCategory.recruit => '진행 중인 모집공고가 없습니다.',
        null => '등록된 게시글이 없습니다.',
      };

  @override
  Widget build(BuildContext context) => PageFrame(
        key: const ValueKey('board'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BOARD',
              style: TextStyle(
                color: AppColors.crimson,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _title,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'KUICS의 새로운 소식과 모집 일정을 확인하세요.',
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final filter in filters)
                  ChoiceChip(
                    label: Text(filter.$2),
                    selected: category == filter.$1,
                    onSelected: (_) => _select(filter.$1),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(64),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (failed)
              LoadError(onRetry: _load)
            else if (posts.isEmpty)
              EmptyState(message: _emptyMessage)
            else ...[
              for (final post in posts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PostCard(post: post),
                ),
              if (hasMore)
                Center(
                  child: OutlinedButton(
                    onPressed: loadingMore ? null : _loadMore,
                    child: Text(loadingMore ? '불러오는 중…' : '더 보기'),
                  ),
                ),
            ],
          ],
        ),
      );
}

String _categoryLabel(PostCategory category) => switch (category) {
      PostCategory.notice => '공지사항',
      PostCategory.recruit => '모집공고',
    };

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}.$month.$day';
}

class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    final published = post.publishedAt;
    final meta = [
      _categoryLabel(post.category),
      if (post.authorName.isNotEmpty) post.authorName,
      if (published != null) _formatDate(published),
    ].join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
        title: Row(
          children: [
            if (post.isPinned) ...[
              const _PinnedBadge(),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                post.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        subtitle: Text(meta),
        children: [
          const Divider(),
          Align(
            alignment: Alignment.centerLeft,
            child: LinkifiedText(text: post.content),
          ),
        ],
      ),
    );
  }
}

class _PinnedBadge extends StatelessWidget {
  const _PinnedBadge();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.crimson,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          '고정',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}
