import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_client.dart';
import '../../format.dart';
import '../../models.dart';
import '../../routes.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'forms.dart';

class AssignmentsTab extends StatelessWidget {
  const AssignmentsTab({
    super.key,
    required this.detail,
    required this.onChanged,
  });

  final ManagedStudyDetail detail;
  final VoidCallback onChanged;

  Future<void> _openForm(
    BuildContext context, {
    AssignmentInfo? assignment,
  }) async {
    final saved = await showDialog<AssignmentInfo>(
      context: context,
      builder: (_) =>
          AssignmentFormDialog(studyId: detail.id, assignment: assignment),
    );
    if (saved == null || !context.mounted) return;
    showMessage(context, assignment == null ? '과제를 등록했습니다.' : '과제를 수정했습니다.');
    onChanged();
  }

  Future<void> _delete(BuildContext context, AssignmentInfo assignment) async {
    final confirmed = await confirmAction(
      context,
      title: '과제 삭제',
      message: '‘${assignment.title}’ 과제를 삭제할까요?\n\n'
          '제출물 ${assignment.submittedCount}건과 파일도 함께 삭제되며 되돌릴 수 없습니다.',
      confirmLabel: '삭제',
      icon: Icons.delete_outline,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ApiClient.instance.deleteAssignment(assignment.id);
      if (!context.mounted) return;
      showMessage(context, '과제를 삭제했습니다.');
      onChanged();
    } catch (error) {
      if (context.mounted) {
        showMessage(
          context,
          errorMessageOf(error, fallback: '과제를 삭제하지 못했습니다.'),
        );
      }
    }
  }

  /// 돌아오면 스터디 관리 화면이 경로 변화를 보고 다시 불러온다.
  void _open(BuildContext context, AssignmentInfo assignment) =>
      context.push<void>(AppRoutes.submissions(detail.id, assignment.id));

  @override
  Widget build(BuildContext context) {
    // 진행 중인 과제(기한 임박 순)를 먼저, 마감된 과제(최근 마감 순)를 나중에 둔다.
    final open = detail.assignments.where((a) => !a.isClosed).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    final closed = detail.assignments.where((a) => a.isClosed).toList()
      ..sort((a, b) => b.dueAt.compareTo(a.dueAt));
    return CenteredListView(
      children: [
        SectionHeader(
          title: '과제 ${detail.assignments.length}개',
          trailing: FilledButton.icon(
            onPressed: () => _openForm(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('과제 등록'),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '과제를 눌러 제출 현황을 확인하고 피드백을 남기세요.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 14),
        if (detail.assignments.isEmpty)
          const WideEmptyState(
            message: '등록된 과제가 없습니다. 과제를 등록하면 참여자가 마이페이지에서 zip 파일로 제출할 수 있습니다.',
          )
        else
          for (final assignment in [...open, ...closed])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AssignmentCard(
                assignment: assignment,
                onOpen: () => _open(context, assignment),
                onEdit: () => _openForm(context, assignment: assignment),
                onDelete: () => _delete(context, assignment),
              ),
            ),
      ],
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.assignment,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final AssignmentInfo assignment;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              assignment.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '기한 ${formatDateTime(assignment.dueAt)}',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: StatusBadge(
                        label: dueLabel(assignment.dueAt),
                        tone: assignment.isClosed
                            ? BadgeTone.neutral
                            : BadgeTone.warning,
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: '과제 메뉴',
                      onSelected: (value) =>
                          value == 'edit' ? onEdit() : onDelete(),
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: MenuItemLabel(Icons.edit_outlined, '수정'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: MenuItemLabel(
                            Icons.delete_outline,
                            '삭제',
                            danger: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (assignment.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      assignment.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      StatusBadge(
                        label: '제출 ${assignment.submittedCount}',
                        tone: BadgeTone.success,
                        icon: Icons.upload_file_outlined,
                      ),
                      StatusBadge(
                        label: '미제출 ${assignment.missingCount}',
                        tone: assignment.missingCount > 0
                            ? BadgeTone.danger
                            : BadgeTone.neutral,
                      ),
                      if (assignment.lateCount > 0)
                        StatusBadge(
                          label: '지각 ${assignment.lateCount}',
                          tone: BadgeTone.warning,
                        ),
                      StatusBadge(
                        label: '미확인 ${assignment.uncheckedCount}',
                        tone: assignment.uncheckedCount > 0
                            ? BadgeTone.info
                            : BadgeTone.neutral,
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
