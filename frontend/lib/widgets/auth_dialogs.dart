import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';
import 'app_dialog.dart';

class LoginDialog extends StatefulWidget {
  const LoginDialog({super.key, this.notice});

  /// 로그인 창을 띄운 이유 (예: 세션이 끊겨 다시 로그인해야 할 때).
  final String? notice;

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  final formKey = GlobalKey<FormState>();
  final studentIdController = TextEditingController();
  final passwordController = TextEditingController();
  final passwordFocus = FocusNode();
  bool obscure = true;
  bool submitting = false;
  String? errorMessage;

  @override
  void dispose() {
    studentIdController.dispose();
    passwordController.dispose();
    passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (submitting || !formKey.currentState!.validate()) return;
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
  Widget build(BuildContext context) {
    // 로그인에 실패하면 안내 대신 실패 이유만 보여준다.
    final notice = errorMessage == null ? widget.notice : null;
    return AppDialog(
      eyebrow: 'KUICS MEMBER',
      title: '학번으로 로그인',
      // 휴대폰 폭에서도 한 줄에 들어가도록 짧게 둔다.
      subtitle: '스터디·과제 회원 전용',
      leading: const Padding(
        padding: EdgeInsets.all(8),
        child: Image(
          image: AssetImage('assets/logo.png'),
          filterQuality: FilterQuality.medium,
        ),
      ),
      maxWidth: 400,
      onClose: submitting ? null : () => Navigator.pop(context),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (notice != null)
              DialogCallout(icon: Icons.lock_clock, message: notice),
            if (errorMessage != null)
              DialogCallout(
                icon: Icons.error_outline,
                message: errorMessage!,
                strong: true,
              ),
            TextFormField(
              controller: studentIdController,
              enabled: !submitting,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              onFieldSubmitted: (_) => passwordFocus.requestFocus(),
              decoration: dialogFieldDecoration(
                context,
                label: '학번',
                icon: Icons.badge_outlined,
              ),
              validator: (value) =>
                  value == null || value.isEmpty ? '학번을 입력해주세요.' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: passwordController,
              focusNode: passwordFocus,
              enabled: !submitting,
              obscureText: obscure,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              decoration: dialogFieldDecoration(
                context,
                label: '비밀번호',
                icon: Icons.lock_outline,
                suffix: _ObscureToggle(
                  obscure: obscure,
                  onPressed: () => setState(() => obscure = !obscure),
                ),
              ),
              validator: (value) =>
                  value == null || value.isEmpty ? '비밀번호를 입력해주세요.' : null,
            ),
            const SizedBox(height: 22),
            DialogPrimaryButton(
              label: '로그인',
              busy: submitting,
              expand: true,
              onPressed: _submit,
            ),
            const SizedBox(height: 14),
            const Text(
              '비밀번호를 잊었다면 운영진에게 문의해주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.textSubtle),
            ),
          ],
        ),
      ),
    );
  }
}

/// 비밀번호 보기/숨기기 버튼.
class _ObscureToggle extends StatelessWidget {
  const _ObscureToggle({required this.obscure, required this.onPressed});
  final bool obscure;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: obscure ? '비밀번호 보기' : '비밀번호 숨기기',
        onPressed: onPressed,
        icon: Icon(
          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
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
  bool obscure = true;
  bool submitting = false;
  String? errorMessage;

  @override
  void dispose() {
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (submitting || !formKey.currentState!.validate()) return;
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
        child: AppDialog(
          eyebrow: 'ACCOUNT SECURITY',
          title: '비밀번호 변경',
          subtitle: '다른 곳에서 쓰지 않는 새 비밀번호로 바꿔주세요.',
          icon: Icons.lock_reset,
          maxWidth: 420,
          // 강제 변경 중에는 창을 닫을 수 없다.
          closable: !widget.forced,
          onClose: submitting ? null : () => Navigator.pop(context),
          actions: [
            // 강제 변경 중에는 다른 계정으로 바꿀 수 있게 로그아웃을 둔다.
            DialogCancelButton(
              label: widget.forced ? '로그아웃' : '취소',
              onPressed: submitting
                  ? null
                  : () => Navigator.pop(
                        context,
                        widget.forced ? PasswordDialogResult.logout : null,
                      ),
            ),
            DialogPrimaryButton(
              label: '변경',
              busy: submitting,
              onPressed: _submit,
            ),
          ],
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.forced && errorMessage == null)
                  const DialogCallout(
                    icon: Icons.waving_hand_outlined,
                    message: '처음 로그인하셨네요. 계속 진행하려면 비밀번호를 바꿔주세요.',
                  ),
                if (errorMessage != null)
                  DialogCallout(
                    icon: Icons.error_outline,
                    message: errorMessage!,
                    strong: true,
                  ),
                TextFormField(
                  controller: passwordController,
                  enabled: !submitting,
                  obscureText: obscure,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: dialogFieldDecoration(
                    context,
                    label: '새 비밀번호',
                    helper: passwordRuleHint,
                    icon: Icons.lock_outline,
                    suffix: _ObscureToggle(
                      obscure: obscure,
                      onPressed: () => setState(() => obscure = !obscure),
                    ),
                  ),
                  validator: validatePasswordComposition,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: confirmController,
                  enabled: !submitting,
                  obscureText: obscure,
                  autofillHints: const [AutofillHints.newPassword],
                  onFieldSubmitted: (_) => _submit(),
                  decoration: dialogFieldDecoration(
                    context,
                    label: '새 비밀번호 확인',
                    icon: Icons.verified_user_outlined,
                  ),
                  validator: (value) => value != passwordController.text
                      ? '비밀번호가 일치하지 않습니다.'
                      : null,
                ),
              ],
            ),
          ),
        ),
      );
}
