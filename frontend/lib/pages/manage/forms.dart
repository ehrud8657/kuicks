import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api_client.dart';
import '../../format.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/common.dart';
import '../../widgets/upload_picker.dart';

/// 폼 위쪽에 보여주는 서버 오류 상자.
class _DialogError extends StatelessWidget {
  const _DialogError(this.message);
  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null) return const SizedBox.shrink();
    return DialogCallout(message: text, strong: true);
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
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: dialogFieldDecoration(
            context,
            label: label,
            icon: icon,
            suffix: const Icon(Icons.expand_more),
            errorText: error,
            enabled: onTap != null,
          ),
          child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      );
}

/// 입력 창 아래의 취소 / 저장 버튼.
List<Widget> _dialogActions(
  BuildContext context, {
  required bool saving,
  required VoidCallback onSubmit,
}) =>
    [
      DialogCancelButton(
        onPressed: saving ? null : () => Navigator.pop(context),
      ),
      DialogPrimaryButton(label: '저장', busy: saving, onPressed: onSubmit),
    ];

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
  Widget build(BuildContext context) => AppDialog(
        title: widget.session == null ? '회차 추가' : '회차 수정',
        maxWidth: 440,
        busy: saving,
        onClose: saving ? null : () => Navigator.pop(context),
        actions: _dialogActions(context, saving: saving, onSubmit: _submit),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DialogError(error),
              TextFormField(
                controller: numberController,
                enabled: !saving,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: dialogFieldDecoration(
                  context,
                  label: '회차 번호',
                  icon: Icons.tag,
                ),
                validator: (value) {
                  final number = int.tryParse(value ?? '');
                  if (number == null || number < 1) {
                    return '1 이상의 숫자를 입력해주세요.';
                  }
                  return fieldErrors['number'];
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: titleController,
                enabled: !saving,
                inputFormatters: [LengthLimitingTextInputFormatter(100)],
                decoration: dialogFieldDecoration(
                  context,
                  label: '주제 (선택)',
                  hint: '예: SQL Injection',
                  icon: Icons.subject,
                ),
                validator: (_) => fieldErrors['title'],
              ),
              const SizedBox(height: 14),
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
    return AppDialog(
      title: widget.assignment == null ? '과제 등록' : '과제 수정',
      maxWidth: 540,
      busy: saving,
      onClose: saving ? null : () => Navigator.pop(context),
      actions: _dialogActions(context, saving: saving, onSubmit: _submit),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DialogError(error),
            TextFormField(
              controller: titleController,
              enabled: !saving,
              inputFormatters: [LengthLimitingTextInputFormatter(150)],
              decoration: dialogFieldDecoration(
                context,
                label: '제목',
                icon: Icons.title,
              ),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? '제목을 입력해주세요.'
                  : fieldErrors['title'],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: descriptionController,
              enabled: !saving,
              minLines: 4,
              maxLines: 10,
              keyboardType: TextInputType.multiline,
              decoration: dialogFieldDecoration(
                context,
                label: '설명 (선택)',
                hint: '과제 내용, 제출물 구성, 참고 링크 등을 적어주세요.',
                alignLabelWithHint: true,
              ),
              validator: (_) => fieldErrors['description'],
            ),
            const SizedBox(height: 14),
            // 화면 폭으로 날짜·시각 칸을 나란히 둘지 정한다.
            if (MediaQuery.sizeOf(context).width < 600)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [dateField, const SizedBox(height: 14), timeField],
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
              const DialogCallout(
                message: '이미 지난 시각입니다. 저장하면 바로 마감된 과제로 표시됩니다.',
                margin: EdgeInsets.only(top: 14),
              ),
          ],
        ),
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
  Widget build(BuildContext context) => AppDialog(
        title: '${widget.memberName}님 피드백',
        subtitle: widget.submission.originalName,
        maxWidth: 540,
        busy: saving,
        onClose: saving ? null : () => Navigator.pop(context),
        actions: _dialogActions(context, saving: saving, onSubmit: _submit),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DialogError(error),
            TextField(
              controller: controller,
              enabled: !saving,
              minLines: 4,
              maxLines: 10,
              keyboardType: TextInputType.multiline,
              decoration: dialogFieldDecoration(
                context,
                hint: '참여자에게 보여줄 피드백을 적어주세요.',
              ),
            ),
            if (!widget.submission.isChecked) ...[
              const SizedBox(height: 10),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.crimson,
                value: markChecked,
                onChanged: saving
                    ? null
                    : (value) => setState(() => markChecked = value ?? false),
                title: const Text('확인 완료로 표시'),
                subtitle: const Text(
                  '참여자 화면에 “스터디장 확인 완료”로 보입니다.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                ),
              ),
            ],
          ],
        ),
      );
}

/// 스터디 게시판 글쓰기·수정. 글을 먼저 저장하고 첨부는 한 파일씩 올린다.
///
/// 저장하면 true를 돌려준다. 새 글은 저장됐는데 일부 파일이 실패한 채 창을 닫아도
/// true를 돌려주어 목록이 새로 고쳐지게 한다.
class StudyPostFormDialog extends StatefulWidget {
  const StudyPostFormDialog({
    super.key,
    required this.studyId,
    this.post,
    this.pickFiles = pickManyFiles,
  });

  final int studyId;

  /// 수정할 글. 없으면 새로 쓴다.
  final StudyPost? post;

  /// 첨부할 파일 선택. 테스트에서 바꿔 끼운다.
  final MultiUploadPicker pickFiles;

  @override
  State<StudyPostFormDialog> createState() => _StudyPostFormDialogState();
}

class _StudyPostFormDialogState extends State<StudyPostFormDialog> {
  final formKey = GlobalKey<FormState>();
  late final titleController =
      TextEditingController(text: widget.post?.title ?? '');
  late final contentController =
      TextEditingController(text: widget.post?.content ?? '');
  late StudyPostKind kind = widget.post?.kind ?? StudyPostKind.notice;
  late bool isPinned = widget.post?.isPinned ?? false;

  /// 이미 올라가 있는 첨부 중 남길 것.
  late final List<PostAttachment> kept = [...?widget.post?.attachments];

  /// 지우기로 한 기존 첨부.
  final List<PostAttachment> removed = [];

  /// 새로 올릴 파일.
  final List<PickedUpload> added = [];

  /// 저장된 글 id. 새 글을 저장한 뒤 파일 업로드가 실패해 다시 저장할 때 글을 두 번 만들지 않게 한다.
  late int? postId = widget.post?.id;

  /// 서버에 무엇이든 반영했는지. 닫을 때 목록을 새로 고칠지 정한다.
  bool changed = false;
  bool saving = false;
  String? error;
  Map<String, String> fieldErrors = const {};

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }

  void _close() => Navigator.pop(context, changed);

  Future<void> _addFiles() async {
    final List<PickedUpload> picked;
    try {
      picked = await widget.pickFiles();
    } catch (_) {
      if (mounted) setState(() => error = '파일을 불러오지 못했습니다. 다시 시도해주세요.');
      return;
    }
    if (!mounted || picked.isEmpty) return;
    final problems = <String>[];
    final accepted = <PickedUpload>[];
    for (final file in picked) {
      final problem = checkUpload(file, maxBytes: maxStudyPostFileBytes);
      if (problem == null) {
        accepted.add(file);
      } else {
        problems.add('${file.name}: $problem');
      }
    }
    setState(() {
      added.addAll(accepted);
      error = problems.isEmpty ? null : problems.join('\n');
    });
  }

  Future<void> _submit() async {
    setState(() => fieldErrors = const {});
    if (!formKey.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    final api = ApiClient.instance;
    try {
      final saved = await api.saveStudyPost(
        studyId: widget.studyId,
        postId: postId,
        kind: kind,
        title: titleController.text.trim(),
        content: contentController.text.trim(),
        isPinned: isPinned,
      );
      postId = saved.id;
      changed = true;
      // 하나씩 처리하고 끝난 것은 목록에서 빼, 실패 후 다시 저장하면 남은 것만 한다.
      while (removed.isNotEmpty) {
        await api.deleteStudyPostFile(removed.first.id);
        if (mounted) setState(() => removed.removeAt(0));
      }
      while (added.isNotEmpty) {
        final file = added.first;
        final uploaded = await api.uploadStudyPostFile(
          saved.id,
          bytes: file.bytes,
          filename: file.name,
        );
        if (mounted) {
          setState(() {
            added.removeAt(0);
            kept.add(uploaded);
          });
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        saving = false;
        fieldErrors = e is ApiException ? e.fieldMessages : const {};
        final message = fieldErrors['file'] ?? errorMessageOf(e);
        if (changed) {
          fieldErrors = const {};
          error = '글은 저장했지만 첨부를 마저 처리하지 못했습니다. '
              '저장을 다시 누르면 남은 파일만 처리합니다.\n$message';
        } else {
          error = fieldErrors.isEmpty ? message : null;
        }
      });
      formKey.currentState!.validate();
    }
  }

  Widget _fileRow({
    required String name,
    required int size,
    required VoidCallback? onRemove,
    bool isNew = false,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Icon(
                isNew ? Icons.upload_file_outlined : Icons.attach_file,
                size: 18,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isNew ? '${formatSize(size)} · 새 파일' : formatSize(size),
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              IconButton(
                tooltip: '첨부 빼기',
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => AppDialog(
        title: widget.post == null ? '게시글 쓰기' : '게시글 수정',
        maxWidth: 580,
        busy: saving,
        onClose: saving ? null : _close,
        actions: [
          DialogCancelButton(onPressed: saving ? null : _close),
          DialogPrimaryButton(label: '저장', busy: saving, onPressed: _submit),
        ],
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DialogError(error),
              SegmentedButton<StudyPostKind>(
                segments: [
                  for (final value in StudyPostKind.values)
                    ButtonSegment(
                      value: value,
                      label: Text(value.label),
                      icon: Icon(
                        value == StudyPostKind.notice
                            ? Icons.campaign_outlined
                            : Icons.folder_outlined,
                      ),
                    ),
                ],
                selected: {kind},
                onSelectionChanged: saving
                    ? null
                    : (value) => setState(() => kind = value.first),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: titleController,
                enabled: !saving,
                inputFormatters: [LengthLimitingTextInputFormatter(200)],
                decoration: dialogFieldDecoration(
                  context,
                  label: '제목',
                  icon: Icons.title,
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? '제목을 입력해주세요.'
                    : fieldErrors['title'],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: contentController,
                enabled: !saving,
                minLines: 5,
                maxLines: 12,
                keyboardType: TextInputType.multiline,
                decoration: dialogFieldDecoration(
                  context,
                  label: '내용 (선택)',
                  hint: '공지 내용이나 자료 설명, 참고 링크 등을 적어주세요.',
                  alignLabelWithHint: true,
                ),
                validator: (_) => fieldErrors['content'],
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.crimson,
                value: isPinned,
                onChanged: saving
                    ? null
                    : (value) => setState(() => isPinned = value ?? false),
                title: const Text('게시판 맨 위에 고정'),
              ),
              const SizedBox(height: 6),
              for (final attachment in kept)
                _fileRow(
                  name: attachment.name,
                  size: attachment.size,
                  onRemove: saving
                      ? null
                      : () => setState(() {
                            kept.remove(attachment);
                            removed.add(attachment);
                          }),
                ),
              for (final file in added)
                _fileRow(
                  name: file.name,
                  size: file.size,
                  isNew: true,
                  onRemove:
                      saving ? null : () => setState(() => added.remove(file)),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: saving ? null : _addFiles,
                  icon: const Icon(Icons.attach_file, size: 18),
                  label: const Text('파일 첨부'),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '사진·문서·압축 파일 등 형식은 상관없습니다. '
                '파일 하나당 최대 ${formatSize(maxStudyPostFileBytes)}이며, '
                '이 스터디 참여자만 받을 수 있습니다.',
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
              ),
            ],
          ),
        ),
      );
}
