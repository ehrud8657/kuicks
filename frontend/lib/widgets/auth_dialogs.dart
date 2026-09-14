import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';

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
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shadowColor: AppColors.navy.withAlpha(90),
      elevation: 24,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LoginHeader(
                onClose: submitting ? null : () => Navigator.pop(context),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (notice != null)
                        _LoginCallout(icon: Icons.lock_clock, message: notice),
                      if (errorMessage != null)
                        _LoginCallout(
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
                        decoration: _fieldDecoration(
                          label: '학번',
                          icon: Icons.badge_outlined,
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? '학번을 입력해주세요.'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: passwordController,
                        focusNode: passwordFocus,
                        enabled: !submitting,
                        obscureText: obscure,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: _fieldDecoration(
                          label: '비밀번호',
                          icon: Icons.lock_outline,
                          suffix: IconButton(
                            tooltip: obscure ? '비밀번호 보기' : '비밀번호 숨기기',
                            onPressed: () => setState(() => obscure = !obscure),
                            icon: Icon(
                              obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? '비밀번호를 입력해주세요.'
                            : null,
                      ),
                      const SizedBox(height: 22),
                      _LoginButton(submitting: submitting, onPressed: _submit),
                      const SizedBox(height: 14),
                      const Text(
                        '비밀번호를 잊었다면 운영진에게 문의해주세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSubtle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    OutlineInputBorder outline(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
    final error = Theme.of(context).colorScheme.error;
    // 초점이 간 칸은 테두리·아이콘·라벨이 모두 크림슨으로 바뀐다.
    Color focusedOr(Set<WidgetState> states, Color other) =>
        states.contains(WidgetState.focused) ? AppColors.crimson : other;
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.surfaceMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      prefixIconColor: WidgetStateColor.resolveWith(
        (states) => focusedOr(states, AppColors.textSubtle),
      ),
      suffixIconColor: WidgetStateColor.resolveWith(
        (states) => focusedOr(states, AppColors.textMuted),
      ),
      labelStyle: const TextStyle(color: AppColors.textMuted),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.error)
              ? error
              : focusedOr(states, AppColors.textMuted),
          fontWeight: FontWeight.w600,
        ),
      ),
      border: outline(AppColors.border),
      enabledBorder: outline(AppColors.border),
      disabledBorder: outline(AppColors.borderLight),
      focusedBorder: outline(AppColors.crimson, 1.6),
      errorBorder: outline(error),
      focusedErrorBorder: outline(error, 1.6),
    );
  }
}

/// 로그인 창 머리: 크림슨 그라데이션 위에 반투명 원으로 명암을 주고 로고를 올린다.
class _LoginHeader extends StatelessWidget {
  const _LoginHeader({required this.onClose});
  final VoidCallback? onClose;

  static Widget _glow(double size, int alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withAlpha(alpha),
        ),
      );

  @override
  Widget build(BuildContext context) => ClipRect(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFD02A46), AppColors.crimson, Color(0xFF7A0F22)],
              stops: [0, 0.45, 1],
            ),
          ),
          child: Stack(
            children: [
              Positioned(right: -46, top: -70, child: _glow(170, 22)),
              Positioned(right: 70, bottom: -60, child: _glow(110, 14)),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 10, 22),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(50),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Image(
                        image: AssetImage('assets/logo.png'),
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'KUICS MEMBER',
                              style: TextStyle(
                                color: Colors.white.withAlpha(190),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              '학번으로 로그인',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            // 휴대폰 폭에서도 한 줄에 들어가도록 짧게 둔다.
                            Text(
                              '스터디·과제 회원 전용',
                              style: TextStyle(
                                color: Colors.white.withAlpha(215),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '닫기',
                      onPressed: onClose,
                      color: Colors.white,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

/// 로그인 창 안의 안내·오류 상자.
class _LoginCallout extends StatelessWidget {
  const _LoginCallout({
    required this.icon,
    required this.message,
    this.strong = false,
  });

  final IconData icon;
  final String message;

  /// 오류처럼 더 눈에 띄어야 할 때 테두리를 진하게 한다.
  final bool strong;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
        decoration: BoxDecoration(
          color: AppColors.crimsonSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.crimson.withAlpha(strong ? 110 : 45),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.crimson),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppColors.crimson,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
}

/// 크림슨 그림자로 살짝 떠 보이는 가로 전체 로그인 버튼.
class _LoginButton extends StatelessWidget {
  const _LoginButton({required this.submitting, required this.onPressed});
  final bool submitting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.crimson.withAlpha(submitting ? 0 : 70),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SizedBox(
          height: 50,
          child: FilledButton(
            onPressed: submitting ? null : onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.crimson,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.crimson.withAlpha(150),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Text('로그인'),
          ),
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
