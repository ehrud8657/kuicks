import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth.dart';
import '../models.dart';
import '../routes.dart';
import '../theme.dart';
import 'common.dart';

/// 로그인한 회원만 볼 수 있는 화면. 주소로 바로 들어와도 서버 권한과 별개로 안내를 먼저 보여준다.
///
/// [detail]이 true면 사이트 상단 메뉴 없이 뜨는 상세 화면용 틀(상단바 + ←)로 감싼다.
class RequireLogin extends StatelessWidget {
  const RequireLogin({super.key, required this.builder, this.detail = false});

  final Widget Function(BuildContext context, Member member) builder;
  final bool detail;

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    if (auth.restoring) {
      return GuardFrame(detail: detail, child: const LoadingView());
    }
    final member = auth.member;
    if (member == null) {
      return GuardFrame(
        detail: detail,
        child: GuardMessage(
          icon: Icons.lock_outline,
          title: '로그인이 필요합니다',
          message: '로그인하면 이 페이지를 볼 수 있습니다.',
          actionLabel: '로그인',
          onAction: auth.showLogin,
        ),
      );
    }
    return builder(context, member);
  }
}

/// 스터디장·운영진만 볼 수 있는 화면. 실제 권한(담당 스터디 여부)은 서버가 다시 검사한다.
class RequireManager extends StatelessWidget {
  const RequireManager({super.key, required this.builder, this.detail = false});

  final Widget Function(BuildContext context, Member member) builder;
  final bool detail;

  @override
  Widget build(BuildContext context) => RequireLogin(
        detail: detail,
        builder: (context, member) {
          if (member.role.canManageStudies) return builder(context, member);
          return GuardFrame(
            detail: detail,
            child: GuardMessage(
              icon: Icons.block,
              title: '볼 수 없는 페이지입니다',
              message: '스터디장·운영진만 이용할 수 있습니다.',
              actionLabel: '홈으로',
              onAction: () => context.go(AppRoutes.home),
            ),
          );
        },
      );
}

/// 안내 화면의 틀. 상세 화면이면 상단바를, 사이트 안쪽이면 일반 페이지 틀을 쓴다.
class GuardFrame extends StatelessWidget {
  const GuardFrame({super.key, required this.child, this.detail = false});
  final Widget child;
  final bool detail;

  @override
  Widget build(BuildContext context) => detail
      ? Scaffold(
          appBar: detailAppBar('KUICS'),
          body: CenteredListView(children: [child]),
        )
      : PageFrame(child: child);
}

class GuardMessage extends StatelessWidget {
  const GuardMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(icon, size: 40, color: AppColors.crimson),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
        ),
      );
}

/// 없는 주소로 들어왔을 때.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key, this.location});
  final String? location;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: detailAppBar('KUICS'),
        body: CenteredListView(
          children: [
            GuardMessage(
              icon: Icons.search_off,
              title: '페이지를 찾을 수 없습니다',
              message: location == null
                  ? '주소가 잘못되었거나 없는 페이지입니다.'
                  : '주소가 잘못되었거나 없는 페이지입니다.\n$location',
              actionLabel: '홈으로',
              onAction: () => context.go(AppRoutes.home),
            ),
          ],
        ),
      );
}
