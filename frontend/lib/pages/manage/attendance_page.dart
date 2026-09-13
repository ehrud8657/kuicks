import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api_client.dart';
import '../../format.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/status_style.dart';

/// 회차 하나의 출석 체크. 여러 명을 표시한 뒤 한 번에 저장한다.
class AttendancePage extends StatefulWidget {
  const AttendancePage({
    super.key,
    required this.sessionId,
    required this.title,
  });

  final int sessionId;
  final String title;

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  AttendanceSheet? sheet;
  Object? loadError;
  bool saving = false;

  /// 화면에서 고른 상태. 참여 기록 id별.
  final statuses = <int, AttendanceStatus?>{};
  final notes = <int, TextEditingController>{};

  /// 마지막으로 저장된 값. 바뀐 게 있는지 비교할 때 쓴다.
  Map<int, (AttendanceStatus?, String)> _saved = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in notes.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get dirty => _saved.entries.any((entry) {
        final (status, note) = entry.value;
        return statuses[entry.key] != status ||
            notes[entry.key]!.text.trim() != note;
      });

  Future<void> _load() async {
    setState(() => loadError = null);
    try {
      final result = await ApiClient.instance.fetchAttendance(widget.sessionId);
      if (mounted) setState(() => _apply(result));
    } catch (error) {
      if (mounted) setState(() => loadError = error);
    }
  }

  void _apply(AttendanceSheet result) {
    sheet = result;
    _saved = {
      for (final record in result.records)
        record.participationId: (record.status, record.note),
    };
    for (final record in result.records) {
      statuses[record.participationId] = record.status;
      // 입력 중인 한글 조합이 끊기지 않도록 컨트롤러는 한 번만 만들고 내용만 맞춘다.
      final controller =
          notes.putIfAbsent(record.participationId, TextEditingController.new);
      if (controller.text != record.note) controller.text = record.note;
    }
  }

  /// 아직 표시하지 않은 사람만 출석으로 채운다. 지각·결석 표시는 그대로 둔다.
  void _fillPresent() => setState(() {
        for (final record in sheet!.records) {
          if (statuses[record.participationId] == null &&
              record.participationStatus != ParticipationStatus.withdrawn) {
            statuses[record.participationId] = AttendanceStatus.present;
          }
        }
      });

  Future<void> _save() async {
    final current = sheet;
    if (current == null) return;
    setState(() => saving = true);
    try {
      final result = await ApiClient.instance.saveAttendance(
        widget.sessionId,
        [
          for (final record in current.records)
            AttendanceRecord(
              participationId: record.participationId,
              memberName: record.memberName,
              studentId: record.studentId,
              participationStatus: record.participationStatus,
              status: statuses[record.participationId],
              note: notes[record.participationId]!.text.trim(),
            ),
        ],
      );
      if (!mounted) return;
      setState(() {
        saving = false;
        _apply(result);
      });
      showMessage(context, '출석을 저장했습니다.');
    } catch (error) {
      if (!mounted) return;
      setState(() => saving = false);
      showMessage(context, errorMessageOf(error, fallback: '출석을 저장하지 못했습니다.'));
    }
  }

  Future<void> _confirmLeave() async {
    final leave = await confirmAction(
      context,
      title: '저장하지 않고 나가기',
      message: '저장하지 않은 출석 변경 사항이 있습니다. 나가면 변경한 내용이 사라집니다.',
      confirmLabel: '나가기',
    );
    if (leave && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final current = sheet;
    final isDirty = current != null && dirty;
    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: detailAppBar(widget.title),
        body: current != null
            ? _buildSheet(current)
            : loadError != null
                ? CenteredListView(
                    children: [
                      LoadError(
                        onRetry: _load,
                        message: errorMessageOf(loadError),
                      ),
                    ],
                  )
                : const LoadingView(),
        bottomNavigationBar: current == null
            ? null
            : _SaveBar(
                dirty: isDirty,
                saving: saving,
                onSave: _save,
              ),
      ),
    );
  }

  Widget _buildSheet(AttendanceSheet current) {
    final counts = <AttendanceStatus?, int>{};
    for (final record in current.records) {
      counts.update(
        statuses[record.participationId],
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    return CenteredListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  current.session.label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatDateWithWeekday(current.session.heldOn),
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final status in AttendanceStatus.values)
                      StatusBadge(
                        label: '${status.label} ${counts[status] ?? 0}',
                        tone: status.tone,
                      ),
                    StatusBadge(label: '미기록 ${counts[null] ?? 0}'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                '참여자 ${current.records.length}명',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed:
                  saving || current.records.isEmpty ? null : _fillPresent,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('미기록 모두 출석'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (current.records.isEmpty)
          const WideEmptyState(message: '출석을 기록할 참여자가 없습니다.')
        else
          for (final record in current.records)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AttendanceRowCard(
                record: record,
                status: statuses[record.participationId],
                note: notes[record.participationId]!,
                enabled: !saving,
                onStatus: (status) => setState(
                  () => statuses[record.participationId] = status,
                ),
                onNoteChanged: () => setState(() {}),
              ),
            ),
      ],
    );
  }
}

class _AttendanceRowCard extends StatelessWidget {
  const _AttendanceRowCard({
    required this.record,
    required this.status,
    required this.note,
    required this.enabled,
    required this.onStatus,
    required this.onNoteChanged,
  });

  final AttendanceRecord record;
  final AttendanceStatus? status;
  final TextEditingController note;
  final bool enabled;
  final ValueChanged<AttendanceStatus?> onStatus;
  final VoidCallback onNoteChanged;

  @override
  Widget build(BuildContext context) {
    final selected = status;
    final withdrawn =
        record.participationStatus == ParticipationStatus.withdrawn;
    final name = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          record.memberName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          withdrawn ? '${record.studentId} · 중도 포기' : record.studentId,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
    );
    final selector = SegmentedButton<AttendanceStatus>(
      segments: [
        for (final value in AttendanceStatus.values)
          ButtonSegment(value: value, label: Text(value.label)),
      ],
      selected: {if (selected != null) selected},
      // 다시 누르면 선택이 풀려 미기록으로 돌아간다.
      emptySelectionAllowed: true,
      showSelectedIcon: false,
      onSelectionChanged: enabled
          ? (value) => onStatus(value.isEmpty ? null : value.first)
          : null,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) && selected != null
              ? selected.tone.background
              : null,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) && selected != null
              ? selected.tone.foreground
              : null,
        ),
      ),
    );
    final noteField = TextField(
      controller: note,
      enabled: enabled,
      onChanged: (_) => onNoteChanged(),
      inputFormatters: [LengthLimitingTextInputFormatter(200)],
      decoration: const InputDecoration(
        isDense: true,
        hintText: '메모 (선택)',
        border: OutlineInputBorder(),
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 760) {
              return Row(
                children: [
                  SizedBox(width: 150, child: name),
                  const SizedBox(width: 12),
                  selector,
                  const SizedBox(width: 12),
                  Expanded(child: noteField),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                name,
                const SizedBox(height: 10),
                selector,
                const SizedBox(height: 10),
                noteField,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.dirty,
    required this.saving,
    required this.onSave,
  });

  final bool dirty;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    dirty ? '저장하지 않은 변경 사항이 있습니다.' : '변경 사항이 모두 저장되었습니다.',
                    maxLines: 2,
                    style: TextStyle(
                      color: dirty ? AppColors.crimson : AppColors.textMuted,
                      fontWeight: dirty ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: dirty && !saving ? onSave : null,
                  icon: saving
                      ? const ButtonSpinner()
                      : const Icon(Icons.save_outlined),
                  label: const Text('저장'),
                ),
              ],
            ),
          ),
        ),
      );
}
