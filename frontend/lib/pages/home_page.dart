import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api_client.dart';
import '../auth.dart';
import '../models.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/manager_panel.dart';
import '../widgets/meteor_shower.dart';
import '../widgets/tap_sequence.dart';

/// KUICS NOW 카드에 채울 실제 데이터.
class _HomeNow {
  const _HomeNow({this.notice, this.semester, this.studies = const []});
  final Post? notice;
  final Semester? semester;
  final List<Study> studies;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<_HomeNow> now;

  static bool _isNarrow(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600;

  @override
  void initState() {
    super.initState();
    now = _load();
    HomeTapSequence.instance.completed.addListener(_onSequence);
  }

  @override
  void dispose() {
    HomeTapSequence.instance.completed.removeListener(_onSequence);
    // 홈을 떠나면 누르던 순서를 버린다.
    HomeTapSequence.instance.reset();
    super.dispose();
  }

  void _onSequence() {
    if (mounted) MeteorShower.show(context);
  }

  Future<_HomeNow> _load() async {
    final client = ApiClient.instance;
    // 두 요청을 병렬로 보내 첫 화면 지연을 줄인다.
    final results = await Future.wait<Object>([
      client.fetchPosts(category: PostCategory.notice),
      client.fetchSemesters(),
    ]);
    final notices = (results[0] as PostPage).posts;
    final semesters = results[1] as List<Semester>;
    // 학기는 최신순으로 내려오므로 첫 항목이 이번 학기다.
    final semester = semesters.isEmpty ? null : semesters.first;
    return _HomeNow(
      notice: notices.isEmpty ? null : notices.first,
      semester: semester,
      studies: semester?.studies ?? const [],
    );
  }

  String _studySummary(_HomeNow data) {
    final semester = data.semester;
    final studies = data.studies;
    if (semester == null) return '등록된 학기가 없습니다.';
    if (studies.isEmpty) return '${semester.name} · 등록된 스터디가 없습니다.';
    if (studies.length == 1) return '${semester.name} · ${studies.first.title}';
    return '${semester.name} · ${studies.first.title} 외 ${studies.length - 1}개';
  }

  @override
  Widget build(BuildContext context) => PageFrame(
        key: const ValueKey('home'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Hero(narrow: _isNarrow(context)),
            if (AuthScope.of(context).member case final member?
                when member.role.canManageStudies) ...[
              const SizedBox(height: 24),
              ManagerPanel(
                // 초기 비밀번호를 바꾸면 담당 스터디를 다시 불러온다.
                key: ValueKey(
                  '${member.studentId}#${AuthScope.of(context).passwordVersion}',
                ),
                member: member,
                onManage: () => context.go(AppRoutes.manage),
              ),
            ],
            const SizedBox(height: 44),
            const Text(
              'KUICS NOW',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24),
            ),
            const SizedBox(height: 18),
            FutureBuilder<_HomeNow>(
              future: now,
              builder: (context, snapshot) {
                final waiting =
                    snapshot.connectionState == ConnectionState.waiting;
                final data = snapshot.data;

                // 첫 화면이라 실패해도 히어로까지 걷어내지 않고 카드 안에만 상태를 적는다.
                String body(String Function(_HomeNow data) pick) {
                  if (waiting) return '불러오는 중…';
                  if (snapshot.hasError || data == null) return '불러오지 못했습니다.';
                  return pick(data);
                }

                return LayoutBuilder(
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
                          body: body(
                            (data) => data.notice?.title ?? '등록된 공지사항이 없습니다.',
                          ),
                          onTap: () => context.go(AppRoutes.board),
                        ),
                        _InfoCard(
                          width: width,
                          icon: Icons.menu_book_outlined,
                          title: '진행 중인 스터디',
                          body: body(_studySummary),
                          onTap: () => context.go(AppRoutes.study),
                        ),
                        // activities API가 아직 없어 채울 데이터가 없다.
                        _InfoCard(
                          width: width,
                          icon: Icons.emoji_events_outlined,
                          title: '최근 활동',
                          body: '준비 중입니다.',
                        ),
                      ],
                    );
                  },
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
    this.onTap,
  });
  final double width;
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: SoftCard(
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 20, color: AppColors.crimson),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      // 눌러서 이동하는 카드만 표시한다.
                      if (onTap != null)
                        const Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: AppColors.textSubtle,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    body,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// 첫 화면 소개 판. 남색 바탕에 아주 옅은 선형 그라데이션과 왼쪽 크림슨 막대만 둔다.
class _Hero extends StatelessWidget {
  const _Hero({required this.narrow});
  final bool narrow;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B2240), AppColors.navy, Color(0xFF06162B)],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withAlpha(36),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            const Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: ColoredBox(color: AppColors.crimson),
            ),
            Padding(
              // 휴대폰 폭에서는 여백과 글자를 줄인다.
              padding: narrow
                  ? const EdgeInsets.fromLTRB(26, 36, 22, 36)
                  : const EdgeInsets.fromLTRB(48, 64, 40, 64),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'KOREA UNIVERSITY\nINSTITUTE of COMPUTER SECURITY',
                    style: TextStyle(
                      color: AppColors.heroAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  SizedBox(height: narrow ? 14 : 18),
                  _HeroTitle(narrow: narrow),
                  SizedBox(height: narrow ? 12 : 16),
                  KeepAllText(
                    'KUICS는 고려대학교 정보대학 소속 대한민국 최고의 보안 학술 동아리입니다.',
                    style: TextStyle(
                      color: AppColors.heroSubtle,
                      fontSize: narrow ? 15.5 : 17,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: narrow ? 22 : 28),
                  FilledButton.icon(
                    onPressed: () => context.go(AppRoutes.study),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 16,
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('스터디 둘러보기'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

/// 첫 화면 제목. "보안" 두 글자는 따로 누름을 받는다(겉보기와 읽기는 그대로).
class _HeroTitle extends StatefulWidget {
  const _HeroTitle({required this.narrow});
  final bool narrow;

  @override
  State<_HeroTitle> createState() => _HeroTitleState();
}

class _HeroTitleState extends State<_HeroTitle> {
  late final TapGestureRecognizer _tap = TapGestureRecognizer()
    ..onTap = HomeTapSequence.instance.titleTapped;

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(
          children: [
            // 올려도 커서 모양이 바뀌지 않게 둔다.
            TextSpan(
              text: '보안',
              recognizer: _tap,
              mouseCursor: SystemMouseCursors.basic,
            ),
            const TextSpan(text: '을 배우고,\n함께 성장합니다.'),
          ],
        ),
        // 화면 낭독기에는 한 문장으로 읽힌다.
        semanticsLabel: '보안을 배우고,\n함께 성장합니다.',
        style: TextStyle(
          color: Colors.white,
          fontSize: widget.narrow ? 28 : 42,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
      );
}
