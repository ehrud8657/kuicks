import 'package:flutter/material.dart';

import '../../api_client.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/status_style.dart';

class ParticipantsTab extends StatelessWidget {
  const ParticipantsTab({
    super.key,
    required this.detail,
    required this.onChanged,
  });

  final ManagedStudyDetail detail;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final withdrawn = detail.participants.length - detail.rosterCount;
    return CenteredListView(
      children: [
        _StudyOverview(detail: detail),
        const SizedBox(height: 24),
        SectionHeader(
          title: withdrawn > 0
              ? '참여자 ${detail.rosterCount}명 · 중도 포기 $withdrawn명'
              : '참여자 ${detail.rosterCount}명',
        ),
        const SizedBox(height: 6),
        const Text(
          '참여자 등록과 삭제는 운영진이 관리자 페이지에서 합니다. 참여 상태는 배지를 눌러 바꿀 수 있습니다.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 14),
        if (detail.participants.isEmpty)
          const WideEmptyState(message: '아직 등록된 참여자가 없습니다.')
        else
          for (final participant in detail.participants)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ParticipantCard(
                studyId: detail.id,
                participant: participant,
                sessionCount: detail.sessions.length,
                assignmentCount: detail.assignments.length,
                onChanged: onChanged,
              ),
            ),
      ],
    );
  }
}

class _StudyOverview extends StatelessWidget {
  const _StudyOverview({required this.detail});
  final ManagedStudyDetail detail;

  @override
  Widget build(BuildContext context) {
    final unchecked = detail.assignments
        .fold<int>(0, (sum, assignment) => sum + assignment.uncheckedCount);
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
                  label: '스터디장 ${detail.leaderName}',
                  tone: BadgeTone.danger,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              detail.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            if (detail.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                detail.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                IconStat(
                  icon: Icons.event_available_outlined,
                  label: '회차 ${detail.sessions.length}',
                ),
                IconStat(
                  icon: Icons.assignment_outlined,
                  label: '과제 ${detail.assignments.length}',
                ),
                IconStat(
                  icon: Icons.mark_email_unread_outlined,
                  label: '미확인 제출물 $unchecked',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticipantCard extends StatelessWidget {
  const _ParticipantCard({
    required this.studyId,
    required this.participant,
    required this.sessionCount,
    required this.assignmentCount,
    required this.onChanged,
  });

  final int studyId;
  final ManagedParticipant participant;
  final int sessionCount;
  final int assignmentCount;
  final VoidCallback onChanged;

  Future<void> _changeStatus(
    BuildContext context,
    ParticipationStatus next,
  ) async {
    if (next == participant.status) return;
    if (next == ParticipationStatus.withdrawn) {
      final confirmed = await confirmAction(
        context,
        title: '중도 포기로 변경',
        message: '${participant.memberName}님을 중도 포기로 바꾸면 과제를 제출할 수 없고, '
            '출석부와 미제출자 집계에서 빠집니다.',
        confirmLabel: '변경',
        icon: Icons.person_off_outlined,
      );
      if (!confirmed || !context.mounted) return;
    }
    try {
      await ApiClient.instance.updateParticipationStatus(
        studyId: studyId,
        participationId: participant.id,
        status: next,
      );
      if (!context.mounted) return;
      showMessage(
        context,
        '${participant.memberName}님의 참여 상태를 변경했습니다. (${next.label})',
      );
      onChanged();
    } catch (error) {
      if (context.mounted) {
        showMessage(
          context,
          errorMessageOf(error, fallback: '참여 상태를 바꾸지 못했습니다.'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rate = participant.attendance.rate(sessionCount);
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
                        participant.memberName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        participant.studentId,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<ParticipationStatus>(
                  tooltip: '참여 상태 변경',
                  onSelected: (value) => _changeStatus(context, value),
                  itemBuilder: (context) => [
                    for (final status in ParticipationStatus.values)
                      CheckedPopupMenuItem(
                        value: status,
                        checked: status == participant.status,
                        child: Text(status.label),
                      ),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusBadge(
                        label: participant.status.label,
                        tone: participant.status.tone,
                      ),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final status in AttendanceStatus.values)
                  StatusBadge(
                    label:
                        '${status.label} ${participant.attendance.count(status)}',
                    tone: participant.attendance.count(status) == 0
                        ? BadgeTone.neutral
                        : status.tone,
                  ),
                StatusBadge(
                  label: '과제 ${participant.submittedCount}/$assignmentCount',
                  icon: Icons.assignment_outlined,
                ),
              ],
            ),
            if (rate != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: rate,
                        minHeight: 6,
                        backgroundColor: AppColors.neutralSoft,
                        color: rate >= .8
                            ? AppColors.success
                            : rate >= .5
                                ? AppColors.warning
                                : AppColors.crimson,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '출석률 ${(rate * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
