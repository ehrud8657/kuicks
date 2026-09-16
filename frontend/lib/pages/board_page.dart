import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api_client.dart';
import '../format.dart';
import '../models.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/linkified_text.dart';

class BoardPage extends StatefulWidget {
  const BoardPage({super.key, this.category});

  /// 주소의 ?category= 값. 없으면 전체.
  final PostCategory? category;
  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  static const filters = <(PostCategory?, String)>[
    (null, '전체'),
    (PostCategory.notice, '공지사항'),
    (PostCategory.recruit, '모집공고'),
  ];

  late PostCategory? category = widget.category;
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

  @override
  void didUpdateWidget(BoardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 브라우저 뒤로가기 등으로 주소의 분류가 바뀐 경우
    if (widget.category != oldWidget.category && widget.category != category) {
      setState(() => category = widget.category);
      _load();
    }
  }

  void _select(PostCategory? value) {
    if (category == value) return;
    setState(() => category = value);
    _load();
    // 분류를 주소에 남기되 방문 기록은 늘리지 않는다.
    replaceLocation(context, AppRoutes.boardOf(value));
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
            PageHeader(
              eyebrow: 'BOARD',
              title: _title,
              subtitle: 'KUICS의 새로운 소식과 모집 일정을 확인하세요.',
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
    return SoftCard(
      accent: true,
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
        subtitle: Text(
          meta,
          style: const TextStyle(color: AppColors.textMuted),
        ),
        children: [
          const Divider(),
          Align(
            alignment: Alignment.centerLeft,
            child: LinkifiedText(text: post.content),
          ),
          if (post.images.isNotEmpty) ...[
            const SizedBox(height: 16),
            PostImages(images: post.images),
          ],
          if (post.files.isNotEmpty) ...[
            const SizedBox(height: 16),
            PostFiles(files: post.files),
          ],
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
          borderRadius: BorderRadius.circular(999),
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

/// 게시글에 붙은 사진. 본문 아래에 바로 보여주고, 누르면 원본을 새 창으로 연다.
class PostImages extends StatelessWidget {
  const PostImages({super.key, required this.images});
  final List<PostAttachment> images;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final image in images)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Material(
                  color: AppColors.surfaceMuted,
                  child: InkWell(
                    onTap: () => launchUrl(Uri.parse(image.url)),
                    child: Image.network(
                      image.url,
                      // 원본이 아주 큰 사진이어도 카드를 밀어내지 않게 높이를 제한한다.
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                      errorBuilder: (context, error, stackTrace) =>
                          _AttachmentRow(attachment: image, failed: true),
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                              ? child
                              : const SizedBox(
                                  height: 120,
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
}

/// 사진이 아닌 첨부(PDF·한글 문서 등). 누르면 내려받는다.
class PostFiles extends StatelessWidget {
  const PostFiles({super.key, required this.files});
  final List<PostAttachment> files;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final file in files)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AttachmentRow(attachment: file),
            ),
        ],
      );
}

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({required this.attachment, this.failed = false});

  final PostAttachment attachment;

  /// 사진을 그리지 못했을 때도 최소한 내려받을 수 있게 같은 줄을 재사용한다.
  final bool failed;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => launchUrl(Uri.parse('${attachment.url}?download=1')),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  failed ? Icons.broken_image_outlined : Icons.description_outlined,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    attachment.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textBody,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  formatSize(attachment.size),
                  style: const TextStyle(
                    color: AppColors.textSubtle,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.download_outlined,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      );
}
