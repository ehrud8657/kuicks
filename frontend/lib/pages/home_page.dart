import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api_client.dart';
import '../auth.dart';
import '../models.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/manager_panel.dart';

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
                key: ValueKey(member.studentId),
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
            hoverColor: AppColors.crimsonSoft.withAlpha(110),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconBadge(icon: icon),
                      const Spacer(),
                      // 눌러서 이동하는 카드만 화살표로 알려준다.
                      if (onTap != null)
                        const Icon(
                          Icons.arrow_forward,
                          size: 20,
                          color: AppColors.crimson,
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
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

/// 첫 화면 소개 판. 남색 그라데이션 위에 크림슨 빛을 번지게 해 명암을 준다.
class _Hero extends StatelessWidget {
  const _Hero({required this.narrow});
  final bool narrow;

  static Widget _glow(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withAlpha(0)]),
        ),
      );

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0E2A4D), AppColors.navy, Color(0xFF040D1A)],
            stops: [0, 0.55, 1],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withAlpha(50),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: narrow ? -150 : -60,
              top: narrow ? -150 : -130,
              child: _glow(
                narrow ? 320 : 440,
                AppColors.crimson.withAlpha(80),
              ),
            ),
            Positioned(
              right: narrow ? 20 : 240,
              bottom: narrow ? -170 : -210,
              child: _glow(
                narrow ? 240 : 340,
                AppColors.heroAccent.withAlpha(34),
              ),
            ),
            Padding(
              // 휴대폰 폭에서는 여백과 글자를 줄여 문구가 음절 중간에서 끊기지 않게 한다.
              padding: narrow
                  ? const EdgeInsets.symmetric(horizontal: 24, vertical: 44)
                  : const EdgeInsets.symmetric(horizontal: 40, vertical: 72),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'KOREA UNIVERSITY\nINSTITUTE of COMPUTER SECURITY',
                    style: TextStyle(
                      color: AppColors.heroAccent,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '보안을 배우고,\n함께 성장합니다.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: narrow ? 30 : 42,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'KUICS는 고려대학교 정보대학 소속 대한민국 최고의 보안 학술 동아리입니다.',
                    style: TextStyle(color: AppColors.heroSubtle, fontSize: 17),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: () => context.go(AppRoutes.study),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 18,
                      ),
                      elevation: 4,
                      shadowColor: Colors.black.withAlpha(120),
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
