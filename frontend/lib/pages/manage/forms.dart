import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api_client.dart';
import '../../format.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// 폼 위쪽에 보여주는 서버 오류 문장.
class _DialogError extends StatelessWidget {
  const _DialogError(this.message);
  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text, style: const TextStyle(color: AppColors.crimson)),
    );
  }
}

/// 누르면 날짜·시각 선택창을 여는 입력칸 모양의 버튼.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.error,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  final String? error;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            suffixIcon: const Icon(Icons.arrow_drop_down),
            errorText: error,
            enabled: onTap != null,
          ),
          child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      );
}

class _DialogActions {
  static List<Widget> build(
    BuildContext context, {
    required bool saving,
    required VoidCallback onSubmit,
  }) =>
      [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: saving ? null : onSubmit,
          child: saving ? const ButtonSpinner() : const Text('저장'),
        ),
      ];
}

/// 회차 추가·수정.
class SessionFormDialog extends StatefulWidget {
  const SessionFormDialog({
    super.key,
    required this.studyId,
    this.session,
    this.nextNumber = 1,
  });

  final int studyId;

  /// 수정할 회차. 없으면 새로 추가한다.
  final StudySessionInfo? session;
  final int nextNumber;

  @override
  State<SessionFormDialog> createState() => _SessionFormDialogState();
}

class _SessionFormDialogState extends State<SessionFormDialog> {
  final formKey = GlobalKey<FormState>();
  late final numberController = TextEditingController(
    text: '${widget.session?.number ?? widget.nextNumber}',
  );
  late final titleController =
      TextEditingController(text: widget.session?.title ?? '');
  late DateTime heldOn =
      widget.session?.heldOn ?? DateUtils.dateOnly(DateTime.now());
  bool saving = false;
  String? error;
  Map<String, String> fieldErrors = const {};

  @override
  void dispose() {
    numberController.dispose();
    titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: heldOn,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: '진행일 선택',
    );
    if (picked != null && mounted) setState(() => heldOn = picked);
  }

  Future<void> _submit() async {
    setState(() => fieldErrors = const {});
    if (!formKey.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final saved = await ApiClient.instance.saveSession(
        studyId: widget.studyId,
        sessionId: widget.session?.id,
        number: int.parse(numberController.text),
        title: titleController.text.trim(),
        heldOn: heldOn,
      );
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        saving = false;
        fieldErrors = e is ApiException ? e.fieldMessages : const {};
        error = fieldErrors.isEmpty ? errorMessageOf(e) : null;
      });
      formKey.currentState!.validate();
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        scrollable: true,
        title: Text(widget.session == null ? '회차 추가' : '회차 수정'),
        content: SizedBox(
          width: 380,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DialogError(error),
                TextFormField(
                  controller: numberController,
                  enabled: !saving,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: '회차 번호',
                    prefixIcon: Icon(Icons.tag),
                  ),
                  validator: (value) {
                    final number = int.tryParse(value ?? '');
                    if (number == null || number < 1) {
                      return '1 이상의 숫자를 입력해주세요.';
                    }
                    return fieldErrors['number'];
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: titleController,
                  enabled: !saving,
                  inputFormatters: [LengthLimitingTextInputFormatter(100)],
                  decoration: const InputDecoration(
                    labelText: '주제 (선택)',
                    hintText: '예: SQL Injection',
                    prefixIcon: Icon(Icons.subject),
                  ),
                  validator: (_) => fieldErrors['title'],
                ),
                const SizedBox(height: 16),
                _PickerField(
                  label: '진행일',
                  value: formatDateWithWeekday(heldOn),
                  icon: Icons.event_outlined,
                  onTap: saving ? null : _pickDate,
                  error: fieldErrors['held_on'],
                ),
              ],
            ),
          ),
        ),
        actions: _DialogActions.build(
          context,
          saving: saving,
          onSubmit: _submit,
        ),
      );
}

/// 과제 등록·수정.
class AssignmentFormDialog extends StatefulWidget {
  const AssignmentFormDialog({
    super.key,
    required this.studyId,
    this.assignment,
  });

  final int studyId;

  /// 수정할 과제. 없으면 새로 등록한다.
  final AssignmentInfo? assignment;

  @override
  State<AssignmentFormDialog> createState() => _AssignmentFormDialogState();
}

class _AssignmentFormDialogState extends State<AssignmentFormDialog> {
  final formKey = GlobalKey<FormState>();
  late final titleController =
      TextEditingController(text: widget.assignment?.title ?? '');
  late final descriptionController =
      TextEditingController(text: widget.assignment?.description ?? '');
  late DateTime dueDate;
  late TimeOfDay dueTime;
  bool saving = false;
  String? error;
  Map<String, String> fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    // 새 과제는 일주일 뒤 밤 11시 59분을 기본 기한으로 둔다.
    final due = widget.assignment?.dueAt.toLocal() ??
        DateUtils.dateOnly(DateTime.now())
            .add(const Duration(days: 7, hours: 23, minutes: 59));
    dueDate = DateUtils.dateOnly(due);
    dueTime = TimeOfDay.fromDateTime(due);
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  DateTime get dueAt => DateTime(
        dueDate.year,
        dueDate.month,
        dueDate.day,
        dueTime.hour,
        dueTime.minute,
      );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: '마감 날짜 선택',
    );
    if (picked != null && mounted) setState(() => dueDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: dueTime,
      helpText: '마감 시각 선택',
    );
    if (picked != null && mounted) setState(() => dueTime = picked);
  }

  Future<void> _submit() async {
    setState(() => fieldErrors = const {});
    if (!formKey.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final saved = await ApiClient.instance.saveAssignment(
        studyId: widget.studyId,
        assignmentId: widget.assignment?.id,
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        dueAt: dueAt,
      );
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        saving = false;
        fieldErrors = e is ApiException ? e.fieldMessages : const {};
        error = fieldErrors.isEmpty ? errorMessageOf(e) : null;
      });
      formKey.currentState!.validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateField = _PickerField(
      label: '마감 날짜',
      value: formatDateWithWeekday(dueDate),
      icon: Icons.event_outlined,
      onTap: saving ? null : _pickDate,
      error: fieldErrors['due_at'],
    );
    final timeField = _PickerField(
      label: '마감 시각',
      value: dueTime.format(context),
      icon: Icons.schedule,
      onTap: saving ? null : _pickTime,
    );
    return AlertDialog(
      scrollable: true,
      title: Text(widget.assignment == null ? '과제 등록' : '과제 수정'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DialogError(error),
              TextFormField(
                controller: titleController,
                enabled: !saving,
                inputFormatters: [LengthLimitingTextInputFormatter(150)],
                decoration: const InputDecoration(labelText: '제목'),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? '제목을 입력해주세요.'
                    : fieldErrors['title'],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descriptionController,
                enabled: !saving,
                minLines: 4,
                maxLines: 10,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  labelText: '설명 (선택)',
                  hintText: '과제 내용, 제출물 구성, 참고 링크 등을 적어주세요.',
                  alignLabelWithHint: true,
                ),
                validator: (_) => fieldErrors['description'],
              ),
              const SizedBox(height: 16),
              // AlertDialog는 내용의 고유 크기를 재므로 LayoutBuilder를 쓸 수 없다.
              // 화면 폭으로 날짜·시각 칸을 나란히 둘지 정한다.
              if (MediaQuery.sizeOf(context).width < 600)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [dateField, const SizedBox(height: 12), timeField],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: dateField),
                    const SizedBox(width: 12),
                    Expanded(child: timeField),
                  ],
                ),
              if (dueAt.isBefore(DateTime.now()))
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    '이미 지난 시각입니다. 저장하면 바로 마감된 과제로 표시됩니다.',
                    style: TextStyle(color: AppColors.crimson, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: _DialogActions.build(
        context,
        saving: saving,
        onSubmit: _submit,
      ),
    );
  }
}

/// 제출물 피드백 작성.
class FeedbackDialog extends StatefulWidget {
  const FeedbackDialog({
    super.key,
    required this.submission,
    required this.memberName,
  });

  final Submission submission;
  final String memberName;

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  late final controller =
      TextEditingController(text: widget.submission.feedback);

  /// 아직 확인하지 않은 제출물이면 피드백 저장과 함께 확인 처리한다.
  bool markChecked = true;
  bool saving = false;
  String? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final saved = await ApiClient.instance.reviewSubmission(
        widget.submission.id,
        feedback: controller.text.trim(),
        reviewStatus: !widget.submission.isChecked && markChecked
            ? ReviewStatus.checked
            : null,
      );
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        saving = false;
        error = errorMessageOf(e, fallback: '피드백을 저장하지 못했습니다.');
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        scrollable: true,
        title: Text('${widget.memberName}님 피드백'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.folder_zip_outlined,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.submission.originalName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _DialogError(error),
              TextField(
                controller: controller,
                enabled: !saving,
                minLines: 4,
                maxLines: 10,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: '참여자에게 보여줄 피드백을 적어주세요.',
                  border: OutlineInputBorder(),
                ),
              ),
              if (!widget.submission.isChecked)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: markChecked,
                  onChanged: saving
                      ? null
                      : (value) => setState(() => markChecked = value ?? false),
                  title: const Text('확인 완료로 표시'),
                ),
            ],
          ),
        ),
        actions: _DialogActions.build(
          context,
          saving: saving,
          onSubmit: _submit,
        ),
      );
}
