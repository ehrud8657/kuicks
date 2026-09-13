import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';

class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(padding: const EdgeInsets.all(24), child: child),
          ),
        ),
      );
}

class LoadError extends StatelessWidget {
  const LoadError({super.key, required this.onRetry, this.message});
  final VoidCallback onRetry;
  @override
/// 페이지 상단 제목 묶음. 예: STUDY / 함께 배우는 KUICS 스터디 / 설명
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
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: const TextStyle(
              color: AppColors.crimson,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: const TextStyle(color: AppColors.textMuted)),
          ],
        ],
      );
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

  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(32),

  /// 서버가 준 오류 문장. 없으면 연결 오류로 안내한다.
  final String? message;

          child: Column(
            children: [
              const Icon(Icons.cloud_off_outlined, size: 36),
              const SizedBox(height: 12),
              Text(
                message ?? '서버에 연결할 수 없습니다.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
            ],
          ),
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, this.message = '등록된 학기가 없습니다.'});
  final String message;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(padding: const EdgeInsets.all(32), child: Text(message)),
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
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final side = math.max(16.0, (constraints.maxWidth - maxWidth) / 2);
          return ListView(
            padding: EdgeInsets.fromLTRB(side, 20, side, 32),
            children: children,
          );
        },
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

/// 확인/취소 창. 확인을 누르면 true.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '확인',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Text(message),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
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
