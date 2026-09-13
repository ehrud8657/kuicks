import 'package:flutter/material.dart';

import 'api_client.dart';
import 'models.dart';
import 'pages/about_page.dart';
import 'pages/board_page.dart';
import 'pages/contact_page.dart';
import 'pages/home_page.dart';
import 'pages/my_page.dart';
import 'pages/placeholder_page.dart';
import 'pages/study_page.dart';
import 'theme.dart';
import 'widgets/auth_dialogs.dart';

enum SitePage { home, about, study, activity, board, contact, myPage }

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
    final wide = MediaQuery.sizeOf(context).width >= 820;
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
              Text(
                'KUICS',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        actions: wide
            ? [
                ...nav,
                const SizedBox(width: 10),
                if (loggedIn)
                  PopupMenuButton<String>(
                    tooltip: '마이페이지 메뉴',
                    onSelected: (value) => value == 'logout'
                        ? _logout()
                        : navigate(SitePage.myPage),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'mypage',
                        child: Text('마이페이지 (${currentMember!.name})'),
                      ),
                      const PopupMenuItem(value: 'logout', child: Text('로그아웃')),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.crimson),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 18,
                            color: AppColors.crimson,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'My Page',
                            style: TextStyle(color: AppColors.crimson),
                          ),
                        ],
                      ),
                    ),
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
                    ListTile(
                      leading: const Icon(Icons.login),
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
              onStudy: () => navigate(SitePage.study),
              onBoard: () => navigate(SitePage.board),
            ),
          SitePage.study => const StudyPage(),
          SitePage.board => const BoardPage(),
          SitePage.about => const AboutPage(),
          SitePage.contact => const ContactPage(),
          SitePage.myPage => currentMember == null
              ? const PlaceholderPage(page: SitePage.myPage)
              : MyPage(
                  member: currentMember!,
                  onLogout: _logout,
                  onChangePassword: () => _promptChangePassword(forced: false),
                ),
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
