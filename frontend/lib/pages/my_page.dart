import 'package:flutter/material.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class MyPage extends StatefulWidget {
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
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  late Future<List<MyStudy>> myStudies;

  @override
  void initState() {
    super.initState();
    myStudies = ApiClient.instance.fetchMyStudies();
  }

  void _reload() =>
      setState(() => myStudies = ApiClient.instance.fetchMyStudies());

  @override
  Widget build(BuildContext context) => PageFrame(
        key: const ValueKey('mypage'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MY PAGE',
              style: TextStyle(
                color: AppColors.crimson,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.member.name}님, 안녕하세요',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '학번 ${widget.member.studentId} · ${widget.member.role.label}',
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: widget.onChangePassword,
                  icon: const Icon(Icons.lock_reset),
                  label: const Text('비밀번호 변경'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: widget.onLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text('로그아웃'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FutureBuilder<List<MyStudy>>(
              future: myStudies,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(64),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                if (snapshot.hasError) return LoadError(onRetry: _reload);
                final data = snapshot.data ?? const <MyStudy>[];
                // 중도 포기(withdrawn)는 어느 카드에도 넣지 않는다.
                final ongoing = data.where((item) => item.isOngoing).toList();
                final completed =
                    data.where((item) => item.isCompleted).toList();
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth >= 700
                        ? (constraints.maxWidth - 16) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _MyStudyCard(
                          width: width,
                          icon: Icons.menu_book_outlined,
                          label: '수강 중인 스터디',
                          studies: ongoing,
                          emptyMessage: '수강 중인 스터디가 없습니다.',
                        ),
                        _MyStudyCard(
                          width: width,
                          icon: Icons.check_circle_outline,
                          label: '완료한 스터디',
                          studies: completed,
                          emptyMessage: '아직 수료한 스터디가 없습니다.',
                        ),
                        _MyPagePlaceholderCard(
                          width: width,
                          icon: Icons.assignment_outlined,
                          label: '과제 제출 현황',
                        ),
                        _MyPagePlaceholderCard(
                          width: width,
                          icon: Icons.emoji_events_outlined,
                          label: '참여 행사 · 대회',
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

class _MyPageCardFrame extends StatelessWidget {
  const _MyPageCardFrame({
    required this.width,
    required this.icon,
    required this.label,
    required this.child,
  });
  final double width;
  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              // 내용이 없을 때도 기존 카드 높이(150)를 유지한다.
              constraints: const BoxConstraints(minHeight: 102),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: AppColors.crimson),
                  const SizedBox(height: 14),
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 6),
                  child,
                ],
              ),
            ),
          ),
        ),
      );
}

class _MyStudyCard extends StatelessWidget {
  const _MyStudyCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.studies,
    required this.emptyMessage,
  });
  final double width;
  final IconData icon;
  final String label;
  final List<MyStudy> studies;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) => _MyPageCardFrame(
        width: width,
        icon: icon,
        label: label,
        child: studies.isEmpty
            ? Text(
                emptyMessage,
                style: const TextStyle(color: AppColors.textSubtle),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${studies.length}개',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.crimson,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final study in studies)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${study.title} · ${study.semester}',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                ],
              ),
      );
}

class _MyPagePlaceholderCard extends StatelessWidget {
  const _MyPagePlaceholderCard({
    required this.width,
    required this.icon,
    required this.label,
  });
  final double width;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => _MyPageCardFrame(
        width: width,
        icon: icon,
        label: label,
        child: const Text(
          '데이터 연동 예정',
          style: TextStyle(color: AppColors.textSubtle),
        ),
      );
}
