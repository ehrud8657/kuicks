import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../pages/board_page.dart';
import '../theme.dart';
import 'common.dart';
import 'linkified_text.dart';

/// 스터디 게시판 글 하나. 참여자 화면과 스터디 관리 화면이 함께 쓴다.
///
/// 제목 줄을 누르면 본문과 첨부가 펼쳐진다. [onEdit]·[onDelete]를 주면
/// 제목 옆에 수정·삭제 메뉴가 붙는다(스터디장·운영진용).
class StudyPostCard extends StatelessWidget {
  const StudyPostCard({
    super.key,
    required this.post,
    this.onEdit,
    this.onDelete,
  });

  final StudyPost post;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  bool get _manageable => onEdit != null || onDelete != null;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (post.authorName.isNotEmpty) post.authorName,
      formatDateTime(post.createdAt),
      if (post.attachments.isNotEmpty) '첨부 ${post.attachments.length}개',
    ].join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (post.isPinned)
                  const StatusBadge(
                    label: '고정',
                    tone: BadgeTone.danger,
                    icon: Icons.push_pin_outlined,
                  ),
                StatusBadge(
                  label: post.kind.label,
                  tone: post.kind == StudyPostKind.notice
                      ? BadgeTone.info
                      : BadgeTone.success,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              post.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            meta,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
        trailing: _manageable
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PopupMenuButton<String>(
                    tooltip: '게시글 메뉴',
                    onSelected: (value) =>
                        value == 'edit' ? onEdit?.call() : onDelete?.call(),
                    itemBuilder: (context) => [
                      if (onEdit != null)
                        const PopupMenuItem(
                          value: 'edit',
                          child: MenuItemLabel(Icons.edit_outlined, '수정'),
                        ),
                      if (onDelete != null)
                        const PopupMenuItem(
                          value: 'delete',
                          child: MenuItemLabel(
                            Icons.delete_outline,
                            '삭제',
                            danger: true,
                          ),
                        ),
                    ],
                  ),
                  const Icon(Icons.expand_more, color: AppColors.textMuted),
                ],
              )
            : null,
        children: [
          const Divider(),
          if (post.content.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: LinkifiedText(
                text: post.content,
                style: const TextStyle(color: AppColors.textBody, height: 1.5),
              ),
            ),
          if (post.images.isNotEmpty) ...[
            const SizedBox(height: 14),
            PostImages(images: post.images),
          ],
          if (post.files.isNotEmpty) ...[
            const SizedBox(height: 14),
            PostFiles(files: post.files),
          ],
          if (post.content.isEmpty && post.attachments.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '내용이 없습니다.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}
