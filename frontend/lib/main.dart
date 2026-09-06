import 'package:flutter/material.dart';
import 'api_client.dart';
import 'models.dart';

void main() => runApp(const KuicsApp());

class KuicsApp extends StatelessWidget {
  const KuicsApp({super.key});

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF071B33);
    const crimson = Color(0xFFB31B34);
    return MaterialApp(
      title: 'KUICS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: crimson, primary: crimson),
        scaffoldBackgroundColor: const Color(0xFFF6F7F9),
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: navy,
          displayColor: navy,
          fontFamily: 'sans-serif',
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: Color(0xFFE3E7EC)),
          ),
        ),
      ),
      home: const SiteShell(),
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final member = await ApiClient().fetchMe();
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
              foregroundColor: page == entry.key
                  ? const Color(0xFFB31B34)
                  : const Color(0xFF344054),
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
              Icon(Icons.shield_outlined, color: Color(0xFFB31B34)),
              SizedBox(width: 9),
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
                        border: Border.all(color: const Color(0xFFB31B34)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 18,
                            color: Color(0xFFB31B34),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'My Page',
                            style: TextStyle(color: Color(0xFFB31B34)),
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
          SitePage.home => HomePage(onStudy: () => navigate(SitePage.study)),
          SitePage.study => const StudyPage(),
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
      await ApiClient().logout();
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
    final changed = await showDialog<bool>(
      barrierDismissible: !forced,
      context: context,
      builder: (context) => ChangePasswordDialog(forced: forced),
    );
    if (changed == true && mounted && currentMember != null) {
      setState(
        () => currentMember = Member(
          studentId: currentMember!.studentId,
          name: currentMember!.name,
          role: currentMember!.role,
          mustChangePassword: false,
        ),
      );
    }
  }
}

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

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onStudy});
  final VoidCallback onStudy;
  @override
  Widget build(BuildContext context) => PageFrame(
    key: const ValueKey('home'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 72),
          decoration: BoxDecoration(
            color: const Color(0xFF071B33),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'KOREA UNIVERSITY\nINFORMATION & CYBER SECURITY',
                style: TextStyle(
                  color: Color(0xFFEF8496),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '보안을 배우고,\n함께 성장합니다.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'KUICS는 고려대학교 정보보호 동아리입니다.',
                style: TextStyle(color: Color(0xFFD0D5DD), fontSize: 17),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onStudy,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('스터디 둘러보기'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 44),
        const Text(
          'KUICS NOW',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 760
                ? (constraints.maxWidth - 32) / 3
                : constraints.maxWidth;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _InfoCard(
                  width: width,
                  icon: Icons.campaign_outlined,
                  title: '최근 공지',
                  body: '2026-2학기 신규 회원 모집 예정',
                ),
                _InfoCard(
                  width: width,
                  icon: Icons.menu_book_outlined,
                  title: '진행 중인 스터디',
                  body: '웹 해킹 기초 외 3개 스터디',
                ),
                _InfoCard(
                  width: width,
                  icon: Icons.emoji_events_outlined,
                  title: '최근 활동',
                  body: 'CTF · 프로젝트 · 세미나 기록',
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.body,
  });
  final double width;
  final IconData icon;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFFB31B34)),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(body, style: const TextStyle(color: Color(0xFF667085))),
          ],
        ),
      ),
    ),
  );
}

class StudyPage extends StatefulWidget {
  const StudyPage({super.key});
  @override
  State<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage> {
  late Future<List<Semester>> semesters;
  int selected = 0;

  @override
  void initState() {
    super.initState();
    semesters = ApiClient().fetchSemesters();
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    key: const ValueKey('study'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'STUDY',
          style: TextStyle(
            color: Color(0xFFB31B34),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '함께 배우는 KUICS 스터디',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          '학기를 선택하고 스터디별 커리큘럼과 수료자를 확인하세요.',
          style: TextStyle(color: Color(0xFF667085)),
        ),
        const SizedBox(height: 28),
        FutureBuilder<List<Semester>>(
          future: semesters,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(64),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snapshot.hasError) {
              return _LoadError(
                onRetry: () =>
                    setState(() => semesters = ApiClient().fetchSemesters()),
              );
            }
            final data = snapshot.data ?? const [];
            if (data.isEmpty) return const _EmptyState();
            if (selected >= data.length) selected = 0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(
                    data.length,
                    (index) => ChoiceChip(
                      label: Text(data[index].name),
                      selected: selected == index,
                      onSelected: (_) => setState(() => selected = index),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (data[selected].studies.isEmpty)
                  const _EmptyState(message: '이 학기에 등록된 스터디가 없습니다.')
                else
                  ...data[selected].studies.map(
                    (study) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: StudyCard(study: study),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class StudyCard extends StatelessWidget {
  const StudyCard({super.key, required this.study});
  final Study study;
  @override
  Widget build(BuildContext context) {
    final completed = study.participants
        .where((p) => p.status == ParticipationStatus.completed)
        .map((p) => p.name)
        .toList();
    final excellent = study.participants
        .where((p) => p.status == ParticipationStatus.excellent)
        .map((p) => p.name)
        .toList();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
        title: Text(
          study.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text('스터디장 · ${study.leader}'),
        children: [
          const Divider(),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(study.description),
          ),
          const SizedBox(height: 16),
          _DetailRow(label: '선이수과목', value: study.prerequisites),
          _DetailRow(label: '권장과목', value: study.recommended),
          const SizedBox(height: 14),
          _People(label: '수료자', names: completed),
          const SizedBox(height: 10),
          _People(label: '우수수료자', names: excellent, accent: true),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(color: Color(0xFF667085))),
        ),
        Expanded(child: Text(value, textAlign: TextAlign.right)),
      ],
    ),
  );
}

class _People extends StatelessWidget {
  const _People({
    required this.label,
    required this.names,
    this.accent = false,
  });
  final String label;
  final List<String> names;
  final bool accent;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label (${names.length})',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: accent ? const Color(0xFFB31B34) : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          names.isEmpty ? '없음' : names.join(', '),
          style: const TextStyle(color: Color(0xFF667085)),
        ),
      ],
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 36),
          const SizedBox(height: 12),
          const Text('서버에 연결할 수 없습니다.'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.message = '등록된 학기가 없습니다.'});
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(32), child: Text(message)),
  );
}

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.page});
  final SitePage page;
  @override
  Widget build(BuildContext context) {
    final content = switch (page) {
      SitePage.about => (
        'ABOUT',
        'KUICS를 소개합니다',
        '동아리 소개, 연혁, 운영진 콘텐츠가 들어갈 공간입니다.',
      ),
      SitePage.activity => (
        'ACTIVITY',
        '우리의 활동 기록',
        'CTF, 대회, 프로젝트 기록을 보여줄 공간입니다.',
      ),
      SitePage.board => (
        'BOARD',
        '공지사항과 모집공고',
        '운영진이 Django Admin에서 등록한 게시글을 보여줄 공간입니다.',
      ),
      SitePage.contact => (
        'CONTACT',
        'KUICS와 연결하기',
        '이메일과 공식 SNS 링크가 들어갈 공간입니다.',
      ),
      _ => ('KUICS', '준비 중입니다', '콘텐츠가 곧 추가됩니다.'),
    };
    return PageFrame(
      key: ValueKey(page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            content.$1,
            style: const TextStyle(
              color: Color(0xFFB31B34),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content.$2,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 28),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(content.$3),
            ),
          ),
        ],
      ),
    );
  }
}

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
      final member = await ApiClient().login(
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
                style: const TextStyle(color: Color(0xFFB31B34)),
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
                  icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
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
      await ApiClient().changePassword(passwordController.text);
      if (mounted) Navigator.pop(context, true);
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
                  style: const TextStyle(color: Color(0xFFB31B34)),
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
        if (!widget.forced)
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
              : const Text('변경'),
        ),
      ],
    ),
  );
}

String _roleLabel(MemberRole role) => switch (role) {
  MemberRole.dormant => '휴회원',
  MemberRole.member => '정회원',
  MemberRole.leader => '스터디장',
  MemberRole.admin => '운영진',
};

class MyPage extends StatelessWidget {
  const MyPage({
    super.key,
    required this.member,
    required this.onLogout,
    required this.onChangePassword,
  });
  final Member member;
  final VoidCallback onLogout;
  final VoidCallback onChangePassword;

  @override
  Widget build(BuildContext context) => PageFrame(
    key: const ValueKey('mypage'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MY PAGE',
          style: TextStyle(
            color: Color(0xFFB31B34),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${member.name}님, 안녕하세요',
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          '학번 ${member.studentId} · ${_roleLabel(member.role)}',
          style: const TextStyle(color: Color(0xFF667085)),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: onChangePassword,
              icon: const Icon(Icons.lock_reset),
              label: const Text('비밀번호 변경'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout),
              label: const Text('로그아웃'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 700
                ? (constraints.maxWidth - 16) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final item in const [
                  ('수강 중인 스터디', Icons.menu_book_outlined),
                  ('과제 제출 현황', Icons.assignment_outlined),
                  ('완료한 스터디', Icons.check_circle_outline),
                  ('참여 행사 · 대회', Icons.emoji_events_outlined),
                ])
                  SizedBox(
                    width: width,
                    height: 150,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(item.$2, color: const Color(0xFFB31B34)),
                            const Spacer(),
                            Text(
                              item.$1,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                            ),
                            const Text(
                              '데이터 연동 예정',
                              style: TextStyle(color: Color(0xFF98A2B3)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
