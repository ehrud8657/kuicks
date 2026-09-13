import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';

class LoginDialog extends StatefulWidget {
  const LoginDialog({super.key});
  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  final formKey = GlobalKey<FormState>();
  final studentIdController = TextEditingController();
  final passwordController = TextEditingController();
  bool obscure = true;
  bool submitting = false;
  String? errorMessage;

  @override
  void dispose() {
    studentIdController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() {
      submitting = true;
      errorMessage = null;
    });
    try {
      final member = await ApiClient.instance.login(
        studentIdController.text.trim(),
        passwordController.text,
      );
      if (mounted) Navigator.pop(context, member);
    } on ApiException catch (e) {
      setState(() {
        submitting = false;
        errorMessage = e.message;
      });
    } catch (_) {
      setState(() {
        submitting = false;
        errorMessage = '서버에 연결할 수 없습니다.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('학번으로 로그인'),
        content: SizedBox(
          width: 360,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (errorMessage != null) ...[
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: AppColors.crimson),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: studentIdController,
                  enabled: !submitting,
                  decoration: const InputDecoration(
                    labelText: '학번',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? '학번을 입력해주세요.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordController,
                  enabled: !submitting,
                  obscureText: obscure,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: '비밀번호',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => obscure = !obscure),
                      icon: Icon(
                          obscure ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? '비밀번호를 입력해주세요.' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: submitting ? null : () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: submitting ? null : _submit,
            child: submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('로그인'),
          ),
        ],
      );
}

/// 비밀번호 변경 창을 닫은 이유. 그냥 닫으면 null.
enum PasswordDialogResult { changed, logout }

const passwordRuleHint = '영문, 숫자, 특수문자를 모두 포함한 10자 이상으로 입력해주세요.';

String? validatePasswordComposition(String? value) {
  if (value == null || value.isEmpty) return '새 비밀번호를 입력해주세요.';
  if (value.length < 10) return '비밀번호는 최소 10자 이상이어야 합니다.';
  if (!RegExp(r'[A-Za-z]').hasMatch(value)) return '영문자를 포함해야 합니다.';
  if (!RegExp(r'[0-9]').hasMatch(value)) return '숫자를 포함해야 합니다.';
  if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) return '특수문자를 포함해야 합니다.';
  return null;
}

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key, required this.forced});
  final bool forced;
  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final formKey = GlobalKey<FormState>();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  bool submitting = false;
  String? errorMessage;

  @override
  void dispose() {
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() {
      submitting = true;
      errorMessage = null;
    });
    try {
      await ApiClient.instance.changePassword(passwordController.text);
      if (mounted) Navigator.pop(context, PasswordDialogResult.changed);
    } on ApiException catch (e) {
      setState(() {
        submitting = false;
        errorMessage = e.message;
      });
    } catch (_) {
      setState(() {
        submitting = false;
        errorMessage = '서버에 연결할 수 없습니다.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !widget.forced,
        child: AlertDialog(
          title: const Text('비밀번호 변경'),
          content: SizedBox(
            width: 360,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.forced) ...[
                    const Text('처음 로그인하셨네요. 계속 진행하려면 비밀번호를 바꿔주세요.'),
                    const SizedBox(height: 12),
                  ],
                  if (errorMessage != null) ...[
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: AppColors.crimson),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: passwordController,
                    enabled: !submitting,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '새 비밀번호',
                      helperText: passwordRuleHint,
                      helperMaxLines: 2,
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: validatePasswordComposition,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmController,
                    enabled: !submitting,
                    obscureText: true,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: '새 비밀번호 확인',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (value) => value != passwordController.text
                        ? '비밀번호가 일치하지 않습니다.'
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            // 강제 변경 중에는 창을 닫을 수 없으므로, 다른 계정으로 바꿀 수 있게 로그아웃을 둔다.
            TextButton(
              onPressed: submitting
                  ? null
                  : () => Navigator.pop(
                        context,
                        widget.forced ? PasswordDialogResult.logout : null,
                      ),
              child: Text(widget.forced ? '로그아웃' : '취소'),
            ),
            FilledButton(
              onPressed: submitting ? null : _submit,
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('변경'),
            ),
          ],
        ),
      );
}
