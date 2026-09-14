import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';
import 'app_dialog.dart';

class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => AppBackdrop(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Padding(
                // 휴대폰 폭에서는 좌우 여백을 줄여 글자 폭을 확보한다.
                padding: MediaQuery.sizeOf(context).width < 600
                    ? const EdgeInsets.fromLTRB(20, 20, 20, 32)
                    : const EdgeInsets.all(24),
                // 내용이 적어도 폭을 꽉 채워, 페이지 전체가 가운데 좁은 기둥으로 몰리지 않게 한다.
                child: SizedBox(width: double.infinity, child: child),
              ),
            ),
          ),
        ),
      );
}

/// 페이지 상단 제목 묶음. 예: ― STUDY / 함께 배우는 KUICS 스터디 / 설명
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 알약 배지 대신 짧은 크림슨 선 + 자간을 넓힌 작은 글자.
        Row(
          children: [
            Container(width: 16, height: 2, color: AppColors.crimson),
            const SizedBox(width: 8),
            Text(
              eyebrow,
              style: const TextStyle(
                color: AppColors.crimson,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: narrow ? 26 : 32,
            fontWeight: FontWeight.w800,
            height: 1.25,
            letterSpacing: -0.3,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          KeepAllText(
            subtitle!,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

/// 카드 머리 선 아이콘. 파스텔 배경 없이 크기와 색만 맞춘다.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.size = 44,
    this.color = AppColors.crimson,
  });
  final IconData icon;

  /// 예전 배지 크기 기준. 아이콘은 그 절반 크기로 그린다.
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Icon(icon, size: size * 0.5, color: color);
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(64),
          child: CircularProgressIndicator(),
        ),
      );
}

class LoadError extends StatelessWidget {
  const LoadError({super.key, required this.onRetry, this.message});
  final VoidCallback onRetry;

  /// 서버가 준 오류 문장. 없으면 연결 오류로 안내한다.
  final String? message;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: SoftCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            child: Column(
              children: [
                const IconBadge(
                  icon: Icons.cloud_off_outlined,
                  color: AppColors.textSubtle,
                ),
                const SizedBox(height: 14),
                Text(
                  message ?? '서버에 연결할 수 없습니다.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textBody),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
      );
}

/// 빈 결과 안내. 가로를 채우고 가운데에 아이콘과 문장을 둔다.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.message = '등록된 학기가 없습니다.',
    this.icon = Icons.inbox_outlined,
  });
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: SoftCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            child: Column(
              children: [
                IconBadge(icon: icon, color: AppColors.textSubtle),
                const SizedBox(height: 14),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// 상태를 나타내는 작은 배지.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = BadgeTone.neutral,
    this.icon,
  });

  final String label;
  final BadgeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: tone.background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: tone.foreground),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: tone.foreground,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

/// 아이콘과 짧은 수치. 예: 👥 참여자 12명
class IconStat extends StatelessWidget {
  const IconStat({super.key, required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      );
}

/// 섹션 제목과 오른쪽 버튼.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      );
}

/// 넓은 화면에서는 가운데로 모으고, 스크롤바는 화면 가장자리에 두는 목록.
class CenteredListView extends StatelessWidget {
  const CenteredListView({
    super.key,
    required this.children,
    this.maxWidth = 960,
  });

  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => AppBackdrop(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = math.max(16.0, (constraints.maxWidth - maxWidth) / 2);
            return ListView(
              padding: EdgeInsets.fromLTRB(side, 20, side, 32),
              children: children,
            );
          },
        ),
      );
}

/// 폭을 꽉 채우는 빈 결과 안내.
class WideEmptyState extends StatelessWidget {
  const WideEmptyState({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: EmptyState(message: message),
      );
}

/// 상세 화면(Navigator.push로 여는 화면)의 흰색 상단바.
AppBar detailAppBar(
  String title, {
  PreferredSizeWidget? bottom,
  List<Widget>? actions,
}) =>
    AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
      ),
      bottom: bottom,
      actions: actions,
    );

/// 화면에 보여줄 오류 문장. 서버가 준 문장이 있으면 그대로 쓴다.
String errorMessageOf(
  Object? error, {
  String fallback = '서버에 연결할 수 없습니다.',
}) =>
    error is ApiException ? error.message : fallback;

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// 확인/취소 창. 확인을 누르면 true. 닫기(✕)나 바깥을 누르면 false.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '확인',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AppDialog(
      title: title,
      maxWidth: 420,
      onClose: () => Navigator.pop(context, false),
      actions: [
        DialogCancelButton(onPressed: () => Navigator.pop(context, false)),
        DialogPrimaryButton(
          label: confirmLabel,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
      child: KeepAllText(
        message,
        style: const TextStyle(
          color: AppColors.textBody,
          fontSize: 14.5,
          height: 1.55,
        ),
      ),
    ),
  );
  return confirmed ?? false;
}

/// 팝업 메뉴 항목의 아이콘 + 글자. 삭제처럼 되돌릴 수 없는 항목은 [danger]로 크림슨 표시.
class MenuItemLabel extends StatelessWidget {
  const MenuItemLabel(this.icon, this.label, {super.key, this.danger = false});

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: danger ? AppColors.crimson : AppColors.textMuted,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: danger ? const TextStyle(color: AppColors.crimson) : null,
            ),
          ),
        ],
      );
}

/// 버튼 안에 넣는 작은 로딩 표시.
class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key, this.color});
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      );
}

/// 화면 바탕. 거의 티 나지 않는 중성 그라데이션만 깐다(번지는 빛 장식은 두지 않는다).
/// 라우트 전환 중 겹쳐 비치지 않도록 화면 틀 안에서 칠한다.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF7F7F5), Color(0xFFF2F3F5)],
          ),
        ),
        child: child,
      );
}

/// 흰색에서 아주 옅은 회백으로 흐르는 카드. [accent]면 왼쪽에 단색 크림슨 구분 막대를 둔다.
/// 안쪽은 그대로 Card라서 잉크 효과와 테스트의 Card 탐색이 유지된다.
class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.accent = false});
  final Widget child;
  final bool accent;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Color(0xFFFCFCFB)],
            ),
          ),
          child: accent
              ? Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 3),
                      child: child,
                    ),
                    const Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 3,
                      child: ColoredBox(color: AppColors.crimson),
                    ),
                  ],
                )
              : child,
        ),
      );
}

/// 한글이 단어 중간에서 줄바꿈되지 않게 한다(CSS `word-break: keep-all`과 같은 효과).
/// 붙어 있는 한글 음절 사이에 줄바꿈 금지 문자(U+2060)를 넣어, 띄어쓰기에서만 줄이 바뀐다.
/// 띄어쓰기 없이 긴 사용자 입력(주소 등)에는 쓰지 않는다 — 좁은 화면에서 넘칠 수 있다.
String keepAll(String text) =>
    text.replaceAllMapped(RegExp(r'([가-힣])(?=[가-힣])'), (m) => '${m[1]}\u2060');

/// [keepAll]을 적용한 글자. 고정 안내 문장(페이지 설명, 소개 문단)에 쓴다.
class KeepAllText extends StatelessWidget {
  const KeepAllText(this.data, {super.key, this.style, this.textAlign});
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => Text(
        keepAll(data),
        semanticsLabel: data,
        style: style,
        textAlign: textAlign,
      );
}
