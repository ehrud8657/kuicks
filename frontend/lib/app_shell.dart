import 'package:flutter/material.dart';

import 'api_client.dart';
import 'models.dart';
import 'pages/about_page.dart';
import 'pages/board_page.dart';
import 'pages/contact_page.dart';
import 'pages/home_page.dart';
import 'pages/manage/manage_page.dart';
import 'pages/my_page.dart';
import 'pages/placeholder_page.dart';
import 'pages/study_page.dart';
import 'theme.dart';
import 'widgets/auth_dialogs.dart';
import 'widgets/common.dart';

enum SitePage { home, about, study, activity, board, contact, myPage, manage }

class SiteShell extends StatefulWidget {
  const SiteShell({super.key});
  @override
  State<SiteShell> createState() => _SiteShellState();
}

class _SiteShellState extends State<SiteShell> {
  SitePage page = SitePage.home;
  Member? currentMember;
  bool restoringSession = true;

  bool get loggedIn => currentMember != null;

  /// 스터디장·운영진이면 스터디 관리 메뉴를 보여준다. 실제 권한은 서버가 다시 검사한다.
  bool get canManage => currentMember?.role.canManageStudies ?? false;

  static const labels = {
    SitePage.home: 'Home',
    SitePage.about: 'About',
    SitePage.study: 'Study',
    SitePage.activity: 'Activity',
    SitePage.board: 'Board',
    SitePage.contact: 'Contact',
  };

  bool _passwordDialogOpen = false;

  @override
  void initState() {
    super.initState();
    ApiClient.passwordChangeRequired.addListener(_onPasswordChangeRequired);
    _restoreSession();
  }

  @override
  void dispose() {
    ApiClient.passwordChangeRequired.removeListener(_onPasswordChangeRequired);
    super.dispose();
  }

  /// 어떤 화면의 API 호출이든 서버가 password_change_required로 막으면 강제 변경 창을 띄운다.
  void _onPasswordChangeRequired() {
    final member = currentMember;
    if (member == null || !mounted) return;
    setState(() => currentMember = member.copyWith(mustChangePassword: true));
    _promptChangePassword(forced: true);
  }

  Future<void> _restoreSession() async {
    try {
      final member = await ApiClient.instance.fetchMe();
      if (!mounted) return;
      setState(() {
        currentMember = member;
        restoringSession = false;
      });
      if (member != null && member.mustChangePassword) {
        _promptChangePassword(forced: true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => restoringSession = false);
    }
  }

  void navigate(SitePage next) {
    setState(() => page = next);
    Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    final member = currentMember;
    // 스터디 관리 버튼과 등급 배지가 붙으면 상단 메뉴가 넓어지므로 전환 폭을 늘린다.
    final wide = MediaQuery.sizeOf(context).width >= (canManage ? 1040 : 820);
    final nav = labels.entries
        .map(
          (entry) => TextButton(
            onPressed: () => navigate(entry.key),
            style: TextButton.styleFrom(
              foregroundColor:
                  page == entry.key ? AppColors.crimson : AppColors.textBody,
            ),
            child: Text(entry.value),
          ),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: wide ? 40 : 16,
        title: InkWell(
          onTap: () => navigate(SitePage.home),
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
                ...nav,
                if (canManage) ...[
                  const SizedBox(width: 8),
                  _ManageNavButton(
                    selected: page == SitePage.manage,
                    onPressed: () => navigate(SitePage.manage),
                  ),
                ],
                const SizedBox(width: 10),
                if (member != null)
                  PopupMenuButton<String>(
                    tooltip: '마이페이지 메뉴',
                    onSelected: (value) => value == 'logout'
                        ? _logout()
                        : navigate(SitePage.myPage),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'mypage',
                        child: Text('마이페이지 (${member.name})'),
                      ),
                      const PopupMenuItem(value: 'logout', child: Text('로그아웃')),
                    ],
                    child: _MyPageButton(member: member),
                  )
                else
                  OutlinedButton(
                    onPressed: () => _showLogin(context),
                    child: const Text('Login'),
                  ),
                const SizedBox(width: 40),
              ]
            : null,
      ),
      drawer: wide
          ? null
          : Drawer(
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
                    ...labels.entries.map(
                      (entry) => ListTile(
                        selected: page == entry.key,
                        title: Text(entry.value),
                        onTap: () => navigate(entry.key),
                      ),
                    ),
                    if (member != null && canManage) ...[
                      const Divider(),
                      ListTile(
                        selected: page == SitePage.manage,
                        leading: const Icon(Icons.dashboard_customize_outlined),
                        title: const Text('스터디 관리'),
                        subtitle: Text('${member.role.label} 메뉴'),
                        onTap: () => navigate(SitePage.manage),
                      ),
                    ],
                    const Divider(),
                    ListTile(
                      leading:
                          Icon(loggedIn ? Icons.person_outline : Icons.login),
                      title: Text(loggedIn ? 'My Page' : 'Login'),
                      onTap: () => loggedIn
                          ? navigate(SitePage.myPage)
                          : _showLogin(context),
                    ),
                    if (loggedIn)
                      ListTile(
                        leading: const Icon(Icons.logout),
                        title: const Text('로그아웃'),
                        onTap: () {
                          Navigator.maybePop(context);
                          _logout();
                        },
                      ),
                  ],
                ),
              ),
            ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: switch (page) {
          SitePage.home => HomePage(
              member: member,
              onStudy: () => navigate(SitePage.study),
              onBoard: () => navigate(SitePage.board),
              onManage: () => navigate(SitePage.manage),
            ),
          SitePage.study => const StudyPage(),
          SitePage.board => const BoardPage(),
          SitePage.about => const AboutPage(),
          SitePage.contact => const ContactPage(),
          SitePage.myPage => member == null
              ? const PlaceholderPage(page: SitePage.myPage)
              : MyPage(
                  member: member,
                  onLogout: _logout,
                  onChangePassword: () => _promptChangePassword(forced: false),
                  onManage: canManage ? () => navigate(SitePage.manage) : null,
                ),
          SitePage.manage => member != null && canManage
              ? ManagePage(member: member)
              : const PlaceholderPage(page: SitePage.manage),
          _ => PlaceholderPage(page: page),
        },
      ),
    );
  }

  Future<void> _showLogin(BuildContext context) async {
    final member = await showDialog<Member>(
      context: context,
      builder: (context) => const LoginDialog(),
    );
    if (member == null || !mounted) return;
    setState(() => currentMember = member);
    if (member.mustChangePassword) {
      _promptChangePassword(forced: true);
    }
  }

  Future<void> _logout() async {
    try {
      await ApiClient.instance.logout();
    } catch (_) {
      // 세션이 이미 끊겨있어도 로컬 상태는 정리한다.
    }
    if (!mounted) return;
    setState(() {
      currentMember = null;
      page = SitePage.home;
    });
  }

  Future<void> _promptChangePassword({required bool forced}) async {
    // 세션 복원과 API 오류가 동시에 요청해도 창은 하나만 띄운다.
    if (_passwordDialogOpen) return;
    _passwordDialogOpen = true;
    final result = await showDialog<PasswordDialogResult>(
      barrierDismissible: !forced,
      context: context,
      builder: (context) => ChangePasswordDialog(forced: forced),
    );
    _passwordDialogOpen = false;
    if (!mounted) return;
    switch (result) {
      case PasswordDialogResult.changed:
        final member = currentMember;
        if (member != null) {
          setState(
            () => currentMember = member.copyWith(mustChangePassword: false),
          );
        }
      case PasswordDialogResult.logout:
        await _logout();
      case null:
        break;
    }
  }
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
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.crimson),
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
