import 'package:flutter/material.dart';

import '../../api_client.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/study_post_card.dart';
import '../../widgets/upload_picker.dart';
import 'forms.dart';

/// 스터디 게시판 관리: 공지·자료를 쓰고 고치고 지운다.
class BoardTab extends StatelessWidget {
  const BoardTab({
    super.key,
    required this.detail,
    required this.onChanged,
    this.pickFiles = pickManyFiles,
  });

  final ManagedStudyDetail detail;
  final VoidCallback onChanged;

  /// 첨부할 파일 선택. 테스트에서 바꿔 끼운다.
  final MultiUploadPicker pickFiles;

  Future<void> _openForm(BuildContext context, {StudyPost? post}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StudyPostFormDialog(
        studyId: detail.id,
        post: post,
        pickFiles: pickFiles,
      ),
    );
    if (saved != true || !context.mounted) return;
    showMessage(context, post == null ? '게시글을 올렸습니다.' : '게시글을 수정했습니다.');
    onChanged();
  }

  Future<void> _delete(BuildContext context, StudyPost post) async {
    final confirmed = await confirmAction(
      context,
      title: '게시글 삭제',
      message: [
        '‘${post.title}’ 글을 삭제할까요?',
        if (post.attachments.isNotEmpty)
          '첨부 ${post.attachments.length}개도 함께 삭제되며 되돌릴 수 없습니다.',
      ].join('\n\n'),
      confirmLabel: '삭제',
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ApiClient.instance.deleteStudyPost(post.id);
      if (!context.mounted) return;
      showMessage(context, '게시글을 삭제했습니다.');
      onChanged();
    } catch (error) {
      if (context.mounted) {
        showMessage(
          context,
          errorMessageOf(error, fallback: '게시글을 삭제하지 못했습니다.'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => CenteredListView(
        children: [
          SectionHeader(
            title: '게시글 ${detail.posts.length}개',
            trailing: FilledButton.icon(
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('글쓰기'),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '공지와 자료는 이 스터디 참여자에게만 보입니다. 참여자는 마이페이지의 스터디 상세에서 확인합니다.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          if (detail.posts.isEmpty)
            const WideEmptyState(
              message: '아직 올린 글이 없습니다. 공지나 발표 자료를 올려보세요.',
            )
          else
            for (final post in detail.posts)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: StudyPostCard(
                  post: post,
                  onEdit: () => _openForm(context, post: post),
                  onDelete: () => _delete(context, post),
                ),
              ),
        ],
      );
}
