import 'package:flutter/material.dart';

import '../theme.dart';

/// 사이트 공통 창(모달) 틀.
///
/// 흰 바탕에 크림슨 그라데이션 머리(아이콘·제목·설명)를 두고, 본문은 스크롤되며 버튼은 아래 오른쪽에 둔다.
/// 로그인·비밀번호 변경·확인 창·스터디 관리 입력 창이 모두 이 틀을 쓴다.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.child,
    this.eyebrow,
    this.subtitle,
    this.icon = Icons.info_outline,
    this.leading,
    this.closable = true,
    this.onClose,
    this.actions = const [],
    this.maxWidth = 440,
  });

  final String title;
  final Widget child;

  /// 제목 위의 작은 영문 머리말. 예: ASSIGNMENT
  final String? eyebrow;
  final String? subtitle;

  /// 머리 영역 흰 카드에 넣을 아이콘. [leading]이 있으면 쓰지 않는다.
  final IconData icon;
  final Widget? leading;

  /// 닫기(✕) 버튼을 둘지. 강제 비밀번호 변경처럼 닫으면 안 되는 창은 false.
  final bool closable;

  /// 닫기 동작. null이면 버튼을 잠시 막는다(저장 중 등).
  final VoidCallback? onClose;
  final List<Widget> actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.navy.withAlpha(90),
        elevation: 24,
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DialogHeader(
                title: title,
                eyebrow: eyebrow,
                subtitle: subtitle,
                leading:
                    leading ?? Icon(icon, size: 26, color: AppColors.crimson),
                closable: closable,
                onClose: onClose,
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    22,
                    24,
                    actions.isEmpty ? 20 : 8,
                  ),
                  child: child,
                ),
              ),
              if (actions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        actions[i],
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
}

/// 창 머리: 크림슨 그라데이션 위에 반투명 원으로 명암을 주고, 흰 카드에 아이콘(또는 로고)을 올린다.
class _DialogHeader extends StatelessWidget {
  const _DialogHeader({
    required this.title,
    required this.leading,
    required this.closable,
    this.eyebrow,
    this.subtitle,
    this.onClose,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget leading;
  final bool closable;
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
                padding: EdgeInsets.fromLTRB(24, 20, closable ? 10 : 24, 20),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
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
                      // 장식용 아이콘·로고는 화면 낭독기가 읽지 않게 한다.
                      child: ExcludeSemantics(child: leading),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      // 제목 묶음을 따로 읽히는 제목 노드로 두고 창의 이름으로 쓴다.
                      // 감싸지 않으면 창 노드에 합쳐져 웹에서 제목이 읽히지 않는다.
                      child: Semantics(
                        container: true,
                        header: true,
                        namesRoute: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (eyebrow != null) ...[
                              Text(
                                eyebrow!,
                                style: TextStyle(
                                  color: Colors.white.withAlpha(190),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                            ],
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                height: 1.3,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                subtitle!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withAlpha(215),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (closable)
                      IconButton(
                        tooltip: '닫기',
                        onPressed: onClose,
                        color: Colors.white,
                        disabledColor: Colors.white.withAlpha(110),
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

/// 창 안의 안내·오류 상자.
class DialogCallout extends StatelessWidget {
  const DialogCallout({
    super.key,
    required this.icon,
    required this.message,
    this.strong = false,
    this.margin = const EdgeInsets.only(bottom: 16),
  });

  final IconData icon;
  final String message;

  /// 오류처럼 더 눈에 띄어야 할 때 테두리를 진하게 한다.
  final bool strong;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
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

/// 크림슨 그림자로 살짝 떠 보이는 주 버튼.
class DialogPrimaryButton extends StatelessWidget {
  const DialogPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// 저장 중이면 글자 대신 로딩 표시를 하고 누를 수 없게 한다.
  final bool busy;

  /// 창 폭을 가득 채우는 큰 버튼 (로그인 창).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final height = expand ? 50.0 : 44.0;
    final active = !busy && onPressed != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.crimson.withAlpha(active ? 70 : 0),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.crimson,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.crimson.withAlpha(150),
          disabledForegroundColor: Colors.white,
          minimumSize: Size(expand ? double.infinity : 84, height),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: TextStyle(
            fontSize: expand ? 16 : 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}

/// 주 버튼 옆의 조용한 보조 버튼 (취소·로그아웃).
class DialogCancelButton extends StatelessWidget {
  const DialogCancelButton({
    super.key,
    required this.onPressed,
    this.label = '취소',
  });

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textMuted,
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      );
}

/// 창 안 입력칸 모양: 연회색 채움, 둥근 테두리, 초점이 가면 테두리·아이콘·라벨이 크림슨.
InputDecoration dialogFieldDecoration(
  BuildContext context, {
  String? label,
  IconData? icon,
  String? hint,
  String? helper,
  String? errorText,
  Widget? suffix,
  bool enabled = true,
  bool alignLabelWithHint = false,
}) {
  OutlineInputBorder outline(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
  final error = Theme.of(context).colorScheme.error;
  Color focusedOr(Set<WidgetState> states, Color other) =>
      states.contains(WidgetState.focused) ? AppColors.crimson : other;
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    helperMaxLines: 2,
    errorText: errorText,
    errorMaxLines: 2,
    enabled: enabled,
    alignLabelWithHint: alignLabelWithHint,
    prefixIcon: icon == null ? null : Icon(icon),
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
    hintStyle: const TextStyle(color: AppColors.textSubtle),
    helperStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
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
