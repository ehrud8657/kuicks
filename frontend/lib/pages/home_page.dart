import 'package:flutter/material.dart';

import '../api_client.dart';
import '../models.dart';
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
  const HomePage({
    super.key,
    this.member,
    required this.onStudy,
    required this.onBoard,
    required this.onManage,
  });

  /// 로그인한 회원. 스터디장·운영진이면 관리 바로가기를 보여준다.
  final Member? member;
  final VoidCallback onStudy;
  final VoidCallback onBoard;
  final VoidCallback onManage;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<_HomeNow> now;

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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 72),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(24),
              ),
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
                    style: TextStyle(color: AppColors.heroSubtle, fontSize: 17),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: widget.onStudy,
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
            if (widget.member case final member?
                when member.role.canManageStudies) ...[
              const SizedBox(height: 24),
              ManagerPanel(
                key: ValueKey(member.studentId),
                member: member,
                onManage: widget.onManage,
              ),
            ],
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
                          onTap: widget.onBoard,
                        ),
                        _InfoCard(
                          width: width,
                          icon: Icons.menu_book_outlined,
                          title: '진행 중인 스터디',
                          body: body(_studySummary),
                          onTap: widget.onStudy,
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
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: AppColors.crimson),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(body,
                      style: const TextStyle(color: AppColors.textMuted)),
                ],
              ),
            ),
          ),
        ),
      );
}
