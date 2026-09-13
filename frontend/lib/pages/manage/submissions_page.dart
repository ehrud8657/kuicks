import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api_client.dart';
import '../../format.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/linkified_text.dart';
import 'forms.dart';

enum SubmissionFilter {
  all('전체'),
  missing('미제출'),
  late('지각 제출'),
  unchecked('미확인');

  const SubmissionFilter(this.label);
  final String label;

  bool matches(SubmissionRow row) => switch (this) {
        SubmissionFilter.all => true,
        SubmissionFilter.missing => row.submission == null,
        SubmissionFilter.late => row.submission?.isLate ?? false,
        SubmissionFilter.unchecked =>
          row.submission != null && !row.submission!.isChecked,
      };
}

/// 과제 하나의 제출 현황: 제출자·제출 시각·파일, 미제출자, 지각 제출, 확인·피드백.
class SubmissionsPage extends StatefulWidget {
  const SubmissionsPage({
    super.key,
    required this.assignmentId,
    required this.title,
  });

  final int assignmentId;
  final String title;

  @override
  State<SubmissionsPage> createState() => _SubmissionsPageState();
}

class _SubmissionsPageState extends State<SubmissionsPage> {
  late Future<SubmissionSheet> sheet;
  SubmissionFilter filter = SubmissionFilter.all;

  /// 확인 상태를 바꾸는 중인 제출물 id.
  final busy = <int>{};

  @override
  void initState() {
    super.initState();
    sheet = ApiClient.instance.fetchSubmissions(widget.assignmentId);
  }

  void _reload() => setState(
        () => sheet = ApiClient.instance.fetchSubmissions(widget.assignmentId),
      );

  Future<void> _toggleReview(Submission submission) async {
    setState(() => busy.add(submission.id));
    try {
      await ApiClient.instance.reviewSubmission(
        submission.id,
        reviewStatus:
            submission.isChecked ? ReviewStatus.pending : ReviewStatus.checked,
      );
      if (mounted) _reload();
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          errorMessageOf(error, fallback: '확인 상태를 바꾸지 못했습니다.'),
        );
      }
    } finally {
      if (mounted) setState(() => busy.remove(submission.id));
    }
  }

  Future<void> _writeFeedback(SubmissionRow row) async {
    final saved = await showDialog<Submission>(
      context: context,
      builder: (_) => FeedbackDialog(
        submission: row.submission!,
        memberName: row.memberName,
      ),
    );
    if (saved == null || !mounted) return;
    showMessage(context, '피드백을 저장했습니다.');
    _reload();
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
        appBar: detailAppBar(widget.title),
        body: FutureBuilder<SubmissionSheet>(
          future: sheet,
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
            final rows = data.rows.where(filter.matches).toList();
            return CenteredListView(
              children: [
                _AssignmentSummary(assignment: data.assignment),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final value in SubmissionFilter.values)
                      ChoiceChip(
                        label: Text(
                          '${value.label} ${data.rows.where(value.matches).length}',
                        ),
                        selected: filter == value,
                        onSelected: (_) => setState(() => filter = value),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (rows.isEmpty)
                  WideEmptyState(
                    message: filter == SubmissionFilter.all
                        ? '이 스터디에 참여자가 없습니다.'
                        : '‘${filter.label}’에 해당하는 참여자가 없습니다.',
                  )
                else
                  for (final row in rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SubmissionCard(
                        row: row,
                        busy: busy.contains(row.submission?.id),
                        onToggleReview: () => _toggleReview(row.submission!),
                        onFeedback: () => _writeFeedback(row),
                        onDownload: () => _download(row.submission!),
                      ),
                    ),
              ],
            );
          },
        ),
      );
}

class _AssignmentSummary extends StatelessWidget {
  const _AssignmentSummary({required this.assignment});
  final AssignmentInfo assignment;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      assignment.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
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
              const SizedBox(height: 4),
              Text(
                '기한 ${formatDateTime(assignment.dueAt)}',
                style: const TextStyle(color: AppColors.textMuted),
              ),
              if (assignment.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                LinkifiedText(
                  text: assignment.description,
                  style:
                      const TextStyle(color: AppColors.textBody, height: 1.5),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  StatusBadge(
                    label: '제출 ${assignment.submittedCount}',
                    tone: BadgeTone.success,
                  ),
                  StatusBadge(
                    label: '미제출 ${assignment.missingCount}',
                    tone: assignment.missingCount > 0
                        ? BadgeTone.danger
                        : BadgeTone.neutral,
                  ),
                  StatusBadge(
                    label: '지각 ${assignment.lateCount}',
                    tone: assignment.lateCount > 0
                        ? BadgeTone.warning
                        : BadgeTone.neutral,
                  ),
                  StatusBadge(
                    label: '미확인 ${assignment.uncheckedCount}',
                    tone: assignment.uncheckedCount > 0
                        ? BadgeTone.info
                        : BadgeTone.neutral,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({
    required this.row,
    required this.busy,
    required this.onToggleReview,
    required this.onFeedback,
    required this.onDownload,
  });

  final SubmissionRow row;
  final bool busy;
  final VoidCallback onToggleReview;
  final VoidCallback onFeedback;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final submission = row.submission;
    final withdrawn = row.participationStatus == ParticipationStatus.withdrawn;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.memberName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        withdrawn ? '${row.studentId} · 중도 포기' : row.studentId,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (submission == null)
                  const StatusBadge(label: '미제출', tone: BadgeTone.danger)
                else if (submission.isLate)
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
              ],
            ),
            if (submission != null) ...[
              const SizedBox(height: 12),
              Material(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onDownload,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.folder_zip_outlined,
                          color: AppColors.crimson,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                submission.originalName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
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
                        const Tooltip(
                          message: '내려받기',
                          child: Icon(
                            Icons.download_outlined,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilterChip(
                    label: Text(submission.isChecked ? '확인 완료' : '확인 전'),
                    selected: submission.isChecked,
                    onSelected: busy ? null : (_) => onToggleReview(),
                  ),
                  TextButton.icon(
                    onPressed: busy ? null : onFeedback,
                    icon: const Icon(Icons.rate_review_outlined, size: 18),
                    label: Text(
                      submission.feedback.isEmpty ? '피드백 작성' : '피드백 수정',
                    ),
                  ),
                  if (submission.isChecked &&
                      submission.feedback.isEmpty &&
                      submission.reviewedByName != null)
                    Text(
                      _reviewedText(submission),
                      style: const TextStyle(
                        color: AppColors.textSubtle,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              if (submission.feedback.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.neutralSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        submission.feedback,
                        style: const TextStyle(
                          color: AppColors.textBody,
                          height: 1.5,
                        ),
                      ),
                      if (submission.reviewedByName != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _reviewedText(submission),
                          style: const TextStyle(
                            color: AppColors.textSubtle,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  static String _reviewedText(Submission submission) {
    final at = submission.reviewedAt;
    return at == null
        ? '${submission.reviewedByName} 확인'
        : '${submission.reviewedByName} 확인 · ${formatDateTime(at)}';
  }
}
