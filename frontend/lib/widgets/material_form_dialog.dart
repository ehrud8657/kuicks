import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_client.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import 'app_dialog.dart';
import 'common.dart';
import 'upload_picker.dart';

/// 활동 자료 올리기·고치기. 자료를 먼저 저장하고 파일은 한 개씩 올린다.
class MaterialFormDialog extends StatefulWidget {
  const MaterialFormDialog({
    super.key,
    required this.activityId,
    this.material,
    this.pickFiles = pickManyFiles,
  });

  final int activityId;

  /// 고칠 자료. 없으면 새로 올린다.
  final ActivityMaterial? material;

  /// 첨부할 파일 선택. 테스트에서 바꿔 끼운다.
  final MultiUploadPicker pickFiles;

  @override
  State<MaterialFormDialog> createState() => _MaterialFormDialogState();
}

class _MaterialFormDialogState extends State<MaterialFormDialog> {
  final formKey = GlobalKey<FormState>();
  late final titleController =
      TextEditingController(text: widget.material?.title ?? '');
  late final descriptionController =
      TextEditingController(text: widget.material?.description ?? '');
  late MaterialStage stage = widget.material?.stage ?? MaterialStage.interim;

  /// 이미 올라가 있는 첨부 중 남길 것.
  late final List<PostAttachment> kept = [...?widget.material?.files];

  /// 지우기로 한 기존 첨부.
  final List<PostAttachment> removed = [];

  /// 새로 올릴 파일.
  final List<PickedUpload> added = [];

  /// 저장된 자료 id. 새 자료를 저장한 뒤 파일 업로드가 실패해 다시 저장할 때 자료를 두 번 만들지 않게 한다.
  late int? materialId = widget.material?.id;

  /// 서버에 무엇이든 반영했는지. 닫을 때 화면을 새로 고칠지 정한다.
  bool changed = false;
  bool saving = false;
  String? error;
  Map<String, String> fieldErrors = const {};

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
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
      final problem = checkUpload(file, maxBytes: maxActivityFileBytes);
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
      final saved = await api.saveMaterial(
        activityId: widget.activityId,
        materialId: materialId,
        stage: stage,
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
      );
      materialId = saved.id;
      changed = true;
      // 하나씩 처리하고 끝난 것은 목록에서 빼, 실패 후 다시 저장하면 남은 것만 한다.
      while (removed.isNotEmpty) {
        await api.deleteMaterialFile(removed.first.id);
        if (mounted) setState(() => removed.removeAt(0));
      }
      while (added.isNotEmpty) {
        final file = added.first;
        final uploaded = await api.uploadMaterialFile(
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
          error = '자료는 저장했지만 첨부를 마저 처리하지 못했습니다. '
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
        title: widget.material == null ? '자료 올리기' : '자료 수정',
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
              if (error case final message?) ...[
                DialogCallout(message: message, strong: true),
              ],
              SegmentedButton<MaterialStage>(
                segments: [
                  for (final value in MaterialStage.values)
                    ButtonSegment(value: value, label: Text(value.label)),
                ],
                selected: {stage},
                showSelectedIcon: false,
                onSelectionChanged: saving
                    ? null
                    : (value) => setState(() => stage = value.first),
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
                  hint: '예: 중간 발표 자료, 최종 보고서',
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
                maxLines: 12,
                keyboardType: TextInputType.multiline,
                decoration: dialogFieldDecoration(
                  context,
                  label: '설명 (선택)',
                  hint: '무엇을 했는지, GitHub·영상 링크 등을 적어주세요.',
                  alignLabelWithHint: true,
                ),
                validator: (_) => fieldErrors['description'],
              ),
              const SizedBox(height: 14),
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
                '보고서·발표 자료는 PDF로 함께 올려두면 오래 지나도 바로 열 수 있습니다. '
                '파일 하나당 최대 ${formatSize(maxActivityFileBytes)}이고, '
                '코드나 영상처럼 큰 결과물은 설명에 링크로 남겨주세요. '
                '올린 자료는 누구나 볼 수 있습니다.',
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
              ),
            ],
          ),
        ),
      );
}
