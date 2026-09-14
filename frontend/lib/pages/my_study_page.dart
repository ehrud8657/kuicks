import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api_client.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/linkified_text.dart';
import '../widgets/status_style.dart';
import '../widgets/zip_picker.dart';

/// 참여자 본인의 스터디 상세: 과제 확인·zip 제출, 피드백, 회차별 내 출석.
class MyStudyPage extends StatefulWidget {
  const MyStudyPage({
    super.key,
    required this.studyId,
    this.title,
    this.pickZip = pickZipFile,
  });

  final int studyId;

  /// 불러오기 전에 상단바에 잠깐 보여줄 제목.
  final String? title;

  /// zip 파일 선택. 테스트에서 바꿔 끼운다.
  final ZipPicker pickZip;

  @override
  State<MyStudyPage> createState() => _MyStudyPageState();
}

class _MyStudyPageState extends State<MyStudyPage> {
  late Future<MyStudyDetail> detail;
  String? _title;

  Future<MyStudyDetail> _fetch() {
    final future = ApiClient.instance.fetchMyStudyDetail(widget.studyId);
    future.then(
      (data) {
        if (mounted && _title != data.title) {
          setState(() => _title = data.title);
        }
      },
      onError: (_) {},
    );
    return future;
  }

  /// 올리는 중인 과제 id. 한 번에 하나만 올린다.
  int? uploading;

  @override
  void initState() {
    super.initState();
    detail = _fetch();
  }

  void _reload() => setState(() {
        detail = _fetch();
      });

  Future<void> _submit(MyAssignment assignment) async {
    final PickedZip? file;
    try {
      file = await widget.pickZip();
    } catch (_) {
      if (mounted) showMessage(context, '파일을 불러오지 못했습니다. 다시 시도해주세요.');
      return;
    }
    if (file == null || !mounted) return;
    final problem = checkZip(file);
    if (problem != null) {
      showMessage(context, problem);
      return;
    }

    final isLate = DateTime.now().isAfter(assignment.dueAt);
    final resubmit = assignment.submission != null;
    final confirmed = await confirmAction(
      context,
      title: resubmit ? '다시 제출' : '과제 제출',
      message: [
        '${file.name} (${formatSize(file.size)})',
        if (isLate) '제출 기한이 지났습니다. 지금 제출하면 지각 제출로 표시됩니다.',
        if (resubmit) '이전에 낸 파일은 이 파일로 바뀌고, 스터디장 확인 상태가 초기화됩니다.',
        if (!isLate && !resubmit) '이 파일로 제출할까요?',
      ].join('\n\n'),
      confirmLabel: '제출',
    );
    if (!confirmed || !mounted) return;

    setState(() => uploading = assignment.id);
    try {
      final saved = await ApiClient.instance.submitAssignment(
        assignment.id,
        bytes: file.bytes,
        filename: file.name,
      );
      if (!mounted) return;
      showMessage(
        context,
        saved.isLate ? '제출했습니다. 기한이 지나 지각 제출로 표시됩니다.' : '과제를 제출했습니다.',
      );
      _reload();
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          errorMessageOf(error, fallback: '과제를 제출하지 못했습니다.'),
        );
      }
    } finally {
      if (mounted) setState(() => uploading = null);
    }
  }

  Future<void> _download(Submission submission) async {
    final opened =
        await launchUrl(ApiClient.submissionDownloadUrl(submission.id));
    if (!opened && mounted) {
      showMessage(context, '파일을 열지 못했습니다: ${submission.originalName}');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: detailAppBar(_title ?? widget.title ?? '스터디'),
        body: FutureBuilder<MyStudyDetail>(
          future: detail,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return CenteredListView(
                children: [
                  LoadError(
                    onRetry: _reload,
                    message: errorMessageOf(snapshot.error),
                  ),
                ],
              );
            }
            final data = snapshot.data;
            if (data == null) return const LoadingView();
            // 진행 중인 과제(기한 임박 순)를 먼저, 마감된 과제(최근 순)를 나중에 둔다.
            final open = data.assignments.where((a) => !a.isClosed).toList()
              ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
            final closed = data.assignments.where((a) => a.isClosed).toList()
              ..sort((a, b) => b.dueAt.compareTo(a.dueAt));
            return CenteredListView(
              children: [
                _StudySummary(detail: data),
                if (!data.canSubmit) ...[
                  const SizedBox(height: 12),
                  _Notice(
                    text:
                        '${data.participationStatus.label} 상태에서는 과제를 제출할 수 없습니다. '
                        '과제와 피드백은 계속 볼 수 있습니다.',
                  ),
                ],
                const SizedBox(height: 28),
                SectionHeader(title: '과제 ${data.assignments.length}개'),
                const SizedBox(height: 6),
                // 좁은 화면에서 문장 중간이 끊기지 않게 두 줄로 나눠 둔다.
                Text(
                  'zip 파일 하나로 제출합니다. (최대 ${formatSize(maxSubmissionBytes)})\n'
                  '기한이 지나도 낼 수 있지만 지각으로 표시됩니다.',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                if (data.assignments.isEmpty)
                  const WideEmptyState(message: '아직 등록된 과제가 없습니다.')
                else
                  for (final assignment in [...open, ...closed])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AssignmentCard(
                        assignment: assignment,
                        canSubmit: data.canSubmit,
                        uploading: uploading == assignment.id,
                        locked: uploading != null,
                        onSubmit: () => _submit(assignment),
                        onDownload: _download,
                      ),
                    ),
                const SizedBox(height: 28),
                const SectionHeader(title: '회차별 출석'),
                const SizedBox(height: 12),
                if (data.sessions.isEmpty)
                  const WideEmptyState(message: '아직 진행한 회차가 없습니다.')
                else
                  _SessionList(sessions: data.sessions),
              ],
            );
          },
        ),
      );
}

class _StudySummary extends StatelessWidget {
  const _StudySummary({required this.detail});
  final MyStudyDetail detail;

  @override
  Widget build(BuildContext context) {
    int count(AttendanceStatus status) =>
        detail.sessions.where((session) => session.attendance == status).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                StatusBadge(label: detail.semester),
                StatusBadge(
                  label: detail.participationStatus.label,
                  tone: detail.participationStatus.tone,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              detail.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '스터디장 · ${detail.leaderName}',
              style: const TextStyle(color: AppColors.textMuted),
            ),
            if (detail.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                detail.description,
                style: const TextStyle(color: AppColors.textBody, height: 1.5),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              '내 출석',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final status in AttendanceStatus.values)
                  StatusBadge(
                    label: '${status.label} ${count(status)}',
                    tone: count(status) == 0 ? BadgeTone.neutral : status.tone,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.warningSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: AppColors.warning, height: 1.4),
              ),
            ),
          ],
        ),
      );
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.assignment,
    required this.canSubmit,
    required this.uploading,
    required this.locked,
    required this.onSubmit,
    required this.onDownload,
  });

  final MyAssignment assignment;
  final bool canSubmit;

  /// 이 과제를 올리는 중.
  final bool uploading;

  /// 어떤 과제든 올리는 중이면 다른 제출 버튼도 잠근다.
  final bool locked;
  final VoidCallback onSubmit;
  final ValueChanged<Submission> onDownload;

  @override
  Widget build(BuildContext context) {
    final submission = assignment.submission;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment.title,
                        maxLines: 3,
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
                const SizedBox(width: 8),
                StatusBadge(
                  label: dueLabel(assignment.dueAt),
                  tone: assignment.isClosed
                      ? BadgeTone.neutral
                      : BadgeTone.warning,
                ),
              ],
            ),
            if (assignment.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              LinkifiedText(
                text: assignment.description,
                style: const TextStyle(color: AppColors.textBody, height: 1.5),
              ),
            ],
            const SizedBox(height: 14),
            if (submission == null)
              _MissingBox(closed: assignment.isClosed)
            else
              _SubmittedBox(
                submission: submission,
                onDownload: () => onDownload(submission),
              ),
            if (canSubmit) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: locked ? null : onSubmit,
                icon: uploading
                    ? const ButtonSpinner()
                    : const Icon(Icons.upload_file_outlined, size: 18),
                label: Text(
                  uploading
                      ? '올리는 중…'
                      : submission == null
                          ? 'zip 파일 제출'
                          : '다시 제출',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MissingBox extends StatelessWidget {
  const _MissingBox({required this.closed});
  final bool closed;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: closed ? AppColors.crimsonSoft : AppColors.neutralSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              closed ? Icons.error_outline : Icons.hourglass_empty,
              size: 18,
              color: closed ? AppColors.crimson : AppColors.textMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                closed ? '제출하지 않았습니다. (기한 지남)' : '아직 제출하지 않았습니다.',
                style: TextStyle(
                  color: closed ? AppColors.crimson : AppColors.textBody,
                ),
              ),
            ),
          ],
        ),
      );
}

class _SubmittedBox extends StatelessWidget {
  const _SubmittedBox({required this.submission, required this.onDownload});
  final Submission submission;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.folder_zip_outlined, color: AppColors.crimson),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        submission.originalName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatSize(submission.size)} · '
                        '${formatDateTime(submission.submittedAt)} 제출',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '내 파일 받기',
                  onPressed: onDownload,
                  icon: const Icon(
                    Icons.download_outlined,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (submission.isLate)
                    const StatusBadge(
                      label: '지각 제출',
                      tone: BadgeTone.warning,
                      icon: Icons.schedule,
                    )
                  else
                    const StatusBadge(
                      label: '기한 내 제출',
                      tone: BadgeTone.success,
                      icon: Icons.check,
                    ),
                  if (submission.isChecked)
                    const StatusBadge(
                      label: '스터디장 확인 완료',
                      tone: BadgeTone.info,
                      icon: Icons.done_all,
                    )
                  else
                    const StatusBadge(label: '확인 대기 중'),
                ],
              ),
            ),
            if (submission.feedback.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '스터디장 피드백',
                        style: TextStyle(
                          color: AppColors.crimson,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        submission.feedback,
                        style: const TextStyle(
                          color: AppColors.textBody,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
}

class _SessionList extends StatelessWidget {
  const _SessionList({required this.sessions});
  final List<MySession> sessions;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (final (index, session) in sessions.indexed) ...[
              if (index > 0)
                const Divider(height: 1, color: AppColors.borderLight),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        '${session.number}',
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.title.isEmpty
                                ? '${session.number}회차'
                                : session.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            formatDateWithWeekday(session.heldOn),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (session.attendance case final attendance?)
                      StatusBadge(
                          label: attendance.label, tone: attendance.tone)
                    else
                      const StatusBadge(label: '미기록'),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
}
