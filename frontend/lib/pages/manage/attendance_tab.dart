import 'package:flutter/material.dart';

import '../../api_client.dart';
import '../../format.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/status_style.dart';
import 'attendance_page.dart';
import 'forms.dart';

class AttendanceTab extends StatelessWidget {
  const AttendanceTab({
    super.key,
    required this.detail,
    required this.onChanged,
  });

  final ManagedStudyDetail detail;
  final VoidCallback onChanged;

  int get _nextNumber =>
      detail.sessions.fold<int>(
        0,
        (last, session) => session.number > last ? session.number : last,
      ) +
      1;

  Future<void> _openForm(
    BuildContext context, {
    StudySessionInfo? session,
  }) async {
    final saved = await showDialog<StudySessionInfo>(
      context: context,
      builder: (_) => SessionFormDialog(
        studyId: detail.id,
        session: session,
        nextNumber: _nextNumber,
      ),
    );
    if (saved == null || !context.mounted) return;
    showMessage(
      context,
      session == null
          ? '회차를 추가했습니다. (${saved.label})'
          : '회차를 수정했습니다. (${saved.label})',
    );
    onChanged();
  }

  Future<void> _delete(BuildContext context, StudySessionInfo session) async {
    final confirmed = await confirmAction(
      context,
      title: '회차 삭제',
      message: '${session.label}\n\n이 회차를 삭제할까요? '
          '출석 기록 ${session.recordedCount}건도 함께 삭제되며 되돌릴 수 없습니다.',
      confirmLabel: '삭제',
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ApiClient.instance.deleteSession(session.id);
      if (!context.mounted) return;
      showMessage(context, '회차를 삭제했습니다.');
      onChanged();
    } catch (error) {
      if (context.mounted) {
        showMessage(
          context,
          errorMessageOf(error, fallback: '회차를 삭제하지 못했습니다.'),
        );
      }
    }
  }

  Future<void> _openAttendance(
    BuildContext context,
    StudySessionInfo session,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AttendancePage(
          sessionId: session.id,
          title: '${session.number}회차 출석 체크',
        ),
      ),
    );
    if (context.mounted) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    // 최근 회차를 위에 둔다.
    final latestFirst = detail.sessions.reversed.toList();
    return CenteredListView(
      children: [
        SectionHeader(
          title: '출석 현황',
          trailing: FilledButton.icon(
            onPressed: () => _openForm(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('회차 추가'),
          ),
        ),
        const SizedBox(height: 14),
        if (detail.sessions.isEmpty)
          const WideEmptyState(message: '아직 회차가 없습니다. 회차를 추가한 뒤 출석을 체크하세요.')
        else ...[
          AttendanceMatrixCard(key: ObjectKey(detail), studyId: detail.id),
          const SizedBox(height: 28),
          const SectionHeader(title: '회차별 출석 체크'),
          const SizedBox(height: 12),
          for (final session in latestFirst)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SessionCard(
                session: session,
                rosterCount: detail.rosterCount,
                onOpen: () => _openAttendance(context, session),
                onEdit: () => _openForm(context, session: session),
                onDelete: () => _delete(context, session),
              ),
            ),
        ],
      ],
    );
  }
}

/// 참여자 × 회차 출석 현황표. 회차가 많으면 가로로 스크롤한다.
class AttendanceMatrixCard extends StatefulWidget {
  const AttendanceMatrixCard({super.key, required this.studyId});
  final int studyId;

  @override
  State<AttendanceMatrixCard> createState() => _AttendanceMatrixCardState();
}

class _AttendanceMatrixCardState extends State<AttendanceMatrixCard> {
  late Future<AttendanceMatrix> matrix =
      ApiClient.instance.fetchAttendanceMatrix(widget.studyId);

  void _reload() => setState(() {
        matrix = ApiClient.instance.fetchAttendanceMatrix(widget.studyId);
      });

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: FutureBuilder<AttendanceMatrix>(
          future: matrix,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        errorMessageOf(
                          snapshot.error,
                          fallback: '출석 현황을 불러오지 못했습니다.',
                        ),
                      ),
                    ),
                    TextButton(onPressed: _reload, child: const Text('다시 시도')),
                  ],
                ),
              );
            }
            final data = snapshot.data!;
            if (data.rows.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('출석을 기록할 참여자가 없습니다.'),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final status in AttendanceStatus.values)
                        StatusBadge(
                          label: '${status.short} ${status.label}',
                          tone: status.tone,
                        ),
                      const StatusBadge(label: '- 미기록'),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: DataTable(
                    headingRowHeight: 44,
                    dataRowMinHeight: 40,
                    dataRowMaxHeight: 44,
                    columnSpacing: 14,
                    horizontalMargin: 12,
                    headingTextStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                    columns: [
                      const DataColumn(label: Text('이름')),
                      for (final session in data.sessions)
                        DataColumn(
                          label: Tooltip(
                            message:
                                '${session.label}\n${formatDateWithWeekday(session.heldOn)}',
                            child: Text('${session.number}회'),
                          ),
                        ),
                      const DataColumn(label: Text('출석률'), numeric: true),
                    ],
                    rows: [
                      for (final row in data.rows)
                        DataRow(
                          cells: [
                            DataCell(
                              Text(
                                row.participationStatus ==
                                        ParticipationStatus.withdrawn
                                    ? '${row.memberName} (포기)'
                                    : row.memberName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            for (final status in row.statuses)
                              DataCell(_StatusCell(status: status)),
                            DataCell(
                              Text(
                                row.rate == null
                                    ? '-'
                                    : '${(row.rate! * 100).round()}%',
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
}

class _StatusCell extends StatelessWidget {
  const _StatusCell({required this.status});
  final AttendanceStatus? status;

  @override
  Widget build(BuildContext context) {
    final value = status;
    if (value == null) {
      return const Text('-', style: TextStyle(color: AppColors.textSubtle));
    }
    return Tooltip(
      message: value.label,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: value.tone.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          value.short,
          style: TextStyle(
            color: value.tone.foreground,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.rosterCount,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final StudySessionInfo session;
  final int rosterCount;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final missing = rosterCount - session.recordedCount;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.crimsonSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${session.number}',
                  style: const TextStyle(
                    color: AppColors.crimson,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              const SizedBox(width: 14),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          formatDateWithWeekday(session.heldOn),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        if (session.recordedCount == 0)
                          const StatusBadge(
                            label: '출석 미기록',
                            tone: BadgeTone.warning,
                          )
                        else if (missing > 0)
                          StatusBadge(
                            label: '미기록 $missing명',
                            tone: BadgeTone.warning,
                          )
                        else
                          const StatusBadge(
                            label: '기록 완료',
                            tone: BadgeTone.success,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '회차 메뉴',
                onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('수정')),
                  PopupMenuItem(value: 'delete', child: Text('삭제')),
                ],
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSubtle),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
