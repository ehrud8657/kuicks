import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api_client.dart';
import '../auth.dart';
import '../models.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/manager_panel.dart';
import '../widgets/refresh_on_return.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key, required this.member});
  final Member member;

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> with RefreshOnReturn {
  late Future<List<MyStudy>> myStudies;

  @override
  void initState() {
    super.initState();
    myStudies = ApiClient.instance.fetchMyStudies();
  }

  // setState 콜백이 Future를 돌려주면 디버그 모드에서 예외가 나므로 블록 본문으로 쓴다.
  void _reload() => setState(() {
        myStudies = ApiClient.instance.fetchMyStudies();
      });

  void _open(MyStudy study) => context.push(AppRoutes.myStudy(study.studyId));

  // 스터디 상세에서 과제를 내고 돌아오면 남은 과제 수를 다시 센다.
  @override
  bool isOwnPath(String path) => path == AppRoutes.me;

  @override
  void onReturn() => _reload();

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
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      AuthScope.of(context).promptChangePassword(forced: false),
                  icon: const Icon(Icons.lock_reset),
                  label: const Text('비밀번호 변경'),
                ),
                OutlinedButton.icon(
                  onPressed: AuthScope.of(context).logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('로그아웃'),
                ),
              ],
            ),
            if (widget.member.role.canManageStudies) ...[
              const SizedBox(height: 24),
              ManagerPanel(
                member: widget.member,
                onManage: () => context.go(AppRoutes.manage),
              ),
            ],
            const SizedBox(height: 24),
            FutureBuilder<List<MyStudy>>(
              future: myStudies,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingView();
                }
                if (snapshot.hasError) {
                  return LoadError(
                    onRetry: _reload,
                    message: errorMessageOf(snapshot.error),
                  );
                }
                final data = snapshot.data ?? const <MyStudy>[];
                // 중도 포기(withdrawn)는 어느 카드에도 넣지 않는다.
                final ongoing = data.where((item) => item.isOngoing).toList();
                final completed =
                    data.where((item) => item.isCompleted).toList();
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth >= 700
                        ? ((constraints.maxWidth - 16) / 2).floorToDouble()
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
                          onOpen: _open,
                        ),
                        _MyStudyCard(
                          width: width,
                          icon: Icons.check_circle_outline,
                          label: '완료한 스터디',
                          studies: completed,
                          emptyMessage: '아직 수료한 스터디가 없습니다.',
                          onOpen: _open,
                        ),
                        _AssignmentSummaryCard(
                          width: width,
                          studies: ongoing,
                          onOpen: _open,
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

/// 누르면 스터디 상세로 들어가는 한 줄.
class _StudyRow extends StatelessWidget {
  const _StudyRow({required this.label, required this.onTap, this.trailing});
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: AppColors.textBody),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textSubtle,
              ),
            ],
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
    required this.onOpen,
  });
  final double width;
  final IconData icon;
  final String label;
  final List<MyStudy> studies;
  final String emptyMessage;
  final ValueChanged<MyStudy> onOpen;

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
                    _StudyRow(
                      label: '${study.title} · ${study.semester}',
                      onTap: () => onOpen(study),
                      trailing: study.pendingAssignmentCount > 0
                          ? StatusBadge(
                              label: '과제 ${study.pendingAssignmentCount}',
                              tone: BadgeTone.danger,
                            )
                          : null,
                    ),
                ],
              ),
      );
}

/// 수강 중인 스터디에서 아직 내지 않은 과제를 모아 보여준다.
class _AssignmentSummaryCard extends StatelessWidget {
  const _AssignmentSummaryCard({
    required this.width,
    required this.studies,
    required this.onOpen,
  });
  final double width;
  final List<MyStudy> studies;
  final ValueChanged<MyStudy> onOpen;

  @override
  Widget build(BuildContext context) {
    final pending =
        studies.where((study) => study.pendingAssignmentCount > 0).toList();
    final total = pending.fold<int>(
        0, (sum, study) => sum + study.pendingAssignmentCount);
    const muted = TextStyle(color: AppColors.textSubtle);
    return _MyPageCardFrame(
      width: width,
      icon: Icons.assignment_outlined,
      label: '과제 제출 현황',
      child: studies.isEmpty
          ? const Text('수강 중인 스터디가 없어 제출할 과제가 없습니다.', style: muted)
          : total == 0
              ? const Text(
                  '지금 제출할 과제가 없습니다. 스터디를 눌러 지난 과제와 피드백을 볼 수 있습니다.',
                  style: muted,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '제출할 과제 $total개',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.crimson,
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final study in pending)
                      _StudyRow(
                        label: study.title,
                        onTap: () => onOpen(study),
                        trailing: Text(
                          '${study.pendingAssignmentCount}개',
                          style: const TextStyle(
                            color: AppColors.crimson,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
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
