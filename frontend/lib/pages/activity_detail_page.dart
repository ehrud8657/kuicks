import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api_client.dart';
import '../auth.dart';
import '../format.dart';
import '../models.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/linkified_text.dart';
import '../widgets/material_form_dialog.dart';
import '../widgets/upload_picker.dart';
import 'activity_page.dart';
import 'board_page.dart';

/// 활동 하나의 개요와 자료(중간·최종 결과물 등). 누구나 볼 수 있고,
/// 참여자(정회원 이상)와 운영진에게는 자료 올리기 버튼이 보인다.
class ActivityDetailPage extends StatefulWidget {
  const ActivityDetailPage({
    super.key,
    required this.kind,
    required this.activityId,
    this.pickFiles = pickManyFiles,
  });

  /// 주소에 적힌 종류. 실제 종류와 다르면 맞는 주소로 바꾼다.
  final ActivityKind kind;
  final int activityId;

  /// 첨부할 파일 선택. 테스트에서 바꿔 끼운다.
  final MultiUploadPicker pickFiles;

  @override
  State<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends State<ActivityDetailPage> {
  late Future<ActivityDetail> detail;

  /// 마지막으로 불러올 때의 로그인 회원. 로그인·로그아웃하면 올리기 권한이 달라지므로 다시 불러온다.
  String? _loadedFor;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final member = AuthScope.maybeOf(context)?.member?.studentId;
    if (!_started || member != _loadedFor) {
      _started = true;
      _loadedFor = member;
      detail = _fetch();
    }
  }

  @override
  void didUpdateWidget(ActivityDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activityId != oldWidget.activityId) detail = _fetch();
  }

  Future<ActivityDetail> _fetch() async {
    final result = await ApiClient.instance.fetchActivity(widget.activityId);
    final kind = result.activity.kind;
    if (kind != widget.kind && mounted) {
      // /activity/events/12 처럼 종류가 틀린 주소로 들어오면 맞는 주소로 바꿔 둔다.
      replaceLocation(
          context, AppRoutes.activityDetail(kind, result.activity.id));
    }
    return result;
  }

  void _reload() => setState(() {
        detail = _fetch();
      });

  Future<void> _openForm(
    ActivityDetail data, {
    ActivityMaterial? material,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => MaterialFormDialog(
        activityId: data.activity.id,
        material: material,
        pickFiles: widget.pickFiles,
      ),
    );
    if (saved != true || !mounted) return;
    showMessage(context, material == null ? '자료를 올렸습니다.' : '자료를 수정했습니다.');
    _reload();
  }

  Future<void> _delete(ActivityMaterial material) async {
    final confirmed = await confirmAction(
      context,
      title: '자료 삭제',
      message: [
        '‘${material.title}’ 자료를 삭제할까요?',
        if (material.files.isNotEmpty)
          '첨부 ${material.files.length}개도 함께 삭제되며 되돌릴 수 없습니다.',
      ].join('\n\n'),
      confirmLabel: '삭제',
    );
    if (!confirmed || !mounted) return;
    try {
      await ApiClient.instance.deleteMaterial(material.id);
      if (!mounted) return;
      showMessage(context, '자료를 삭제했습니다.');
      _reload();
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          errorMessageOf(error, fallback: '자료를 삭제하지 못했습니다.'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
        key: ValueKey('activity-${widget.activityId}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () => GoRouter.maybeOf(context)
                  ?.go(AppRoutes.activityOf(kind: widget.kind)),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('활동 목록'),
            ),
            const SizedBox(height: 12),
            FutureBuilder<ActivityDetail>(
              future: detail,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingView();
                }
                final data = snapshot.data;
                if (snapshot.hasError || data == null) {
                  final error = snapshot.error;
                  if (error is ApiException && error.statusCode == 404) {
                    return const EmptyState(
                      message: '없는 활동이거나 아직 공개되지 않았습니다.',
                      icon: Icons.search_off,
                    );
                  }
                  return LoadError(onRetry: _reload);
                }
                return _content(data);
              },
            ),
          ],
        ),
      );

  Widget _content(ActivityDetail data) {
    final activity = data.activity;
    final headline = activityHeadline(activity);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          eyebrow: '${activity.semester} · ${activity.kind.label}',
          title: activity.title,
          subtitle: headline.isEmpty ? null : headline,
        ),
        const SizedBox(height: 24),
        _Overview(detail: data),
        const SizedBox(height: 32),
        SectionHeader(
          title: '자료 ${data.materials.length}개',
          trailing: data.canContribute
              ? FilledButton.icon(
                  onPressed: () => _openForm(data),
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('자료 올리기'),
                )
              : null,
        ),
        const SizedBox(height: 14),
        if (data.materials.isEmpty)
          EmptyState(
            message: data.canContribute
                ? '아직 올린 자료가 없습니다. 제안서나 중간 발표 자료부터 올려보세요.'
                : '아직 올라온 자료가 없습니다.',
            icon: Icons.folder_open_outlined,
          )
        else
          for (final material in data.materials)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: MaterialCard(
                material: material,
                onEdit: material.canEdit
                    ? () => _openForm(data, material: material)
                    : null,
                onDelete: material.canEdit ? () => _delete(material) : null,
              ),
            ),
      ],
    );
  }
}

/// 개요 카드: 상태·태그, 소개, 기간·결과·장소, 참여자.
class _Overview extends StatelessWidget {
  const _Overview({required this.detail});
  final ActivityDetail detail;

  @override
  Widget build(BuildContext context) {
    final activity = detail.activity;
    final period = activityPeriod(activity);
    final rows = <(String, String)>[
      if (period != null) ('기간', period),
      if (detail.teamName.isNotEmpty) ('참가 팀', detail.teamName),
      if (activity.kind == ActivityKind.contest && activity.result.isNotEmpty)
        ('결과', activity.result),
      if (detail.location.isNotEmpty) ('장소', detail.location),
    ];
    return SizedBox(
      width: double.infinity,
      child: SoftCard(
        accent: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  StatusBadge(
                    label: activity.status.label,
                    tone: activityStatusTone(activity.status),
                  ),
                  for (final tag in activity.tags)
                    StatusBadge(label: '#$tag', tone: BadgeTone.danger),
                ],
              ),
              if (activity.summary.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  activity.summary,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
              if (detail.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                LinkifiedText(
                  text: detail.description,
                  style:
                      const TextStyle(color: AppColors.textBody, height: 1.55),
                ),
              ],
              if (rows.isNotEmpty) ...[
                const SizedBox(height: 14),
                for (final (label, value) in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 72,
                          child: Text(
                            label,
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                        Expanded(child: Text(value)),
                      ],
                    ),
                  ),
              ],
              if (activity.members.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  '참여자 ${activity.members.length}명',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final member in activity.members)
                      StatusBadge(
                        label: member.isLeader
                            ? '${member.name} · 팀장'
                            : member.name,
                        tone: member.isLeader
                            ? BadgeTone.info
                            : BadgeTone.neutral,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

BadgeTone _stageTone(MaterialStage stage) => switch (stage) {
      MaterialStage.proposal => BadgeTone.warning,
      MaterialStage.interim => BadgeTone.info,
      MaterialStage.finalReport => BadgeTone.success,
      MaterialStage.other => BadgeTone.neutral,
    };

/// 자료 하나. 아카이브라 접지 않고 설명과 첨부를 바로 보여준다.
class MaterialCard extends StatelessWidget {
  const MaterialCard({
    super.key,
    required this.material,
    this.onEdit,
    this.onDelete,
  });

  final ActivityMaterial material;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final date = material.date;
    final meta = [
      if (material.authorName.isNotEmpty) material.authorName,
      if (date != null) formatDate(date),
    ].join(' · ');
    return SizedBox(
      width: double.infinity,
      child: SoftCard(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 8, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusBadge(
                    label: material.stage.label,
                    tone: _stageTone(material.stage),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      meta,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (onEdit != null || onDelete != null)
                    PopupMenuButton<String>(
                      tooltip: '자료 메뉴',
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
                    )
                  else
                    const SizedBox(height: 40),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Text(
                      material.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (material.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      LinkifiedText(
                        text: material.description,
                        style: const TextStyle(
                          color: AppColors.textBody,
                          height: 1.5,
                        ),
                      ),
                    ],
                    if (material.images.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      PostImages(images: material.images),
                    ],
                    if (material.documents.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      PostFiles(files: material.documents),
                    ],
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
