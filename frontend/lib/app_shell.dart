import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth.dart';
import 'models.dart';
import 'routes.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// 상단 메뉴·메뉴 서랍·로그인 버튼이 있는 사이트 공통 틀. [child]에 현재 경로의 화면이 들어온다.
class SiteShell extends StatelessWidget {
  const SiteShell({super.key, required this.location, required this.child});

  /// 현재 주소의 경로 부분. 예: /study, /me
  final String location;
  final Widget child;

  static const _menu = <(String, String)>[
    ('Home', AppRoutes.home),
    ('About', AppRoutes.about),
    ('Study', AppRoutes.study),
    ('Activity', AppRoutes.activity),
    ('Board', AppRoutes.board),
    ('Contact', AppRoutes.contact),
  ];

  bool _isActive(String route) => route == AppRoutes.home
      ? location == AppRoutes.home
      : location == route || location.startsWith('$route/');

  /// 브라우저 탭에 보일 제목.
  String get _pageTitle {
    if (_isActive(AppRoutes.manage)) return '스터디 관리 · KUICS';
    if (_isActive(AppRoutes.me)) return '마이페이지 · KUICS';
    for (final (label, route) in _menu.skip(1)) {
      if (_isActive(route)) return '$label · KUICS';
    }
    return 'KUICS';
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final member = auth.member;
    // 스터디 관리 버튼과 등급 배지가 붙으면 상단 메뉴가 넓어지므로 전환 폭을 늘린다.
    final wide =
        MediaQuery.sizeOf(context).width >= (auth.canManage ? 1100 : 880);
    return Title(
      title: _pageTitle,
      color: AppColors.crimson,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          titleSpacing: wide ? 40 : 16,
          title: InkWell(
            onTap: () => context.go(AppRoutes.home),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image(
                  image: AssetImage('assets/logo.png'),
                  height: 36,
                  filterQuality: FilterQuality.medium,
                ),
                SizedBox(width: 10),
                // 메뉴가 늘어 제목 자리가 좁아지면 넘치지 않고 글자를 자른다.
                Flexible(
                  child: Text(
                    'KUICS',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: wide
              ? [
                  for (final (label, route) in _menu)
                    _NavItem(
                      label: label,
                      active: _isActive(route),
                      onPressed: () => context.go(route),
                    ),
                  if (auth.canManage) ...[
                    const SizedBox(width: 8),
                    _ManageNavButton(
                      selected: _isActive(AppRoutes.manage),
                      onPressed: () => context.go(AppRoutes.manage),
                    ),
                  ],
                  const SizedBox(width: 10),
                  if (member != null)
                    PopupMenuButton<String>(
                      tooltip: '마이페이지 메뉴',
                      onSelected: (value) => value == 'logout'
                          ? auth.logout()
                          : context.go(AppRoutes.me),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'mypage',
                          child: MenuItemLabel(
                            Icons.person_outline,
                            '마이페이지 (${member.name})',
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'logout',
                          child: MenuItemLabel(Icons.logout, '로그아웃'),
                        ),
                      ],
                      child: _MyPageButton(member: member),
                    )
                  else
                    OutlinedButton(
                      onPressed: auth.showLogin,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 11,
                        ),
                      ),
                      child: const Text('Login'),
                    ),
                  const SizedBox(width: 40),
                ]
              : null,
        ),
        drawer: wide ? null : _SiteDrawer(isActive: _isActive, menu: _menu),
        body: child,
      ),
    );
  }
}

class _SiteDrawer extends StatelessWidget {
  const _SiteDrawer({required this.isActive, required this.menu});
  final bool Function(String route) isActive;
  final List<(String, String)> menu;

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final member = auth.member;

    // 서랍을 먼저 닫고 이동한다. (서랍이 열린 채 남지 않게)
    void close(VoidCallback then) {
      Scaffold.of(context).closeDrawer();
      then();
    }

    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            const ListTile(
              leading: Image(
                image: AssetImage('assets/logo.png'),
                width: 32,
                height: 32,
                filterQuality: FilterQuality.medium,
              ),
              title: Text(
                'KUICS',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final (label, route) in menu)
              ListTile(
                selected: isActive(route),
                title: Text(label),
                onTap: () => close(() => context.go(route)),
              ),
            if (member != null && auth.canManage) ...[
              const Divider(),
              ListTile(
                selected: isActive(AppRoutes.manage),
                leading: const Icon(Icons.dashboard_customize_outlined),
                title: const Text('스터디 관리'),
                subtitle: Text('${member.role.label} 메뉴'),
                onTap: () => close(() => context.go(AppRoutes.manage)),
              ),
            ],
            const Divider(),
            ListTile(
              selected: member != null && isActive(AppRoutes.me),
              leading:
                  Icon(member != null ? Icons.person_outline : Icons.login),
              title: Text(member != null ? 'My Page' : 'Login'),
              onTap: () => close(
                () => member != null
                    ? context.go(AppRoutes.me)
                    : auth.showLoginThenHome(),
              ),
            ),
            if (member != null)
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('로그아웃'),
                onTap: () => close(auth.logout),
              ),
          ],
        ),
      ),
    );
  }
}

/// 상단 메뉴 한 칸. 마우스를 올리면 옅은 알약, 현재 메뉴는 연크림슨 알약에 굵은 크림슨 글자.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.active,
    required this.onPressed,
  });
  final String label;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: active ? AppColors.crimson : AppColors.textBody,
            backgroundColor: active ? AppColors.crimsonSoft : null,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            minimumSize: const Size(0, 38),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: TextStyle(
              // 버튼 글자 모양을 직접 정하면 테마 글꼴이 빠지므로 한글 글꼴을 다시 지정한다.
              fontFamily: 'Pretendard',
              fontSize: 14.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ).copyWith(
            overlayColor: WidgetStatePropertyAll(AppColors.navy.withAlpha(12)),
          ),
          child: Text(label),
        ),
      );
}

/// 스터디장·운영진에게만 보이는 상단 메뉴 버튼. 일반 메뉴와 구분되게 채워진 모양으로 둔다.
class _ManageNavButton extends StatelessWidget {
  const _ManageNavButton({required this.selected, required this.onPressed});
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: selected ? AppColors.crimson : AppColors.crimsonSoft,
          foregroundColor: selected ? Colors.white : AppColors.crimson,
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        icon: const Icon(Icons.dashboard_customize_outlined, size: 18),
        label: const Text('스터디 관리'),
      );
}

class _MyPageButton extends StatelessWidget {
  const _MyPageButton({required this.member});
  final Member member;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.crimson.withAlpha(150)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_outline,
              size: 18,
              color: AppColors.crimson,
            ),
            const SizedBox(width: 6),
            const Text('My Page', style: TextStyle(color: AppColors.crimson)),
            if (member.role.canManageStudies) ...[
              const SizedBox(width: 8),
              StatusBadge(label: member.role.label, tone: BadgeTone.danger),
            ],
          ],
        ),
      );
}
