import 'package:flutter/material.dart';

import '../../api_client.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'study_manage_page.dart';

/// 스터디 관리 첫 화면: 관리할 수 있는 스터디 목록.
class ManagePage extends StatefulWidget {
  const ManagePage({super.key, required this.member});
  final Member member;

  @override
  State<ManagePage> createState() => _ManagePageState();
}

class _ManagePageState extends State<ManagePage> {
  late Future<List<ManagedStudy>> studies;

  /// 선택한 학기. null이면 전체.
  String? semester;

  @override
  void initState() {
    super.initState();
    studies = ApiClient.instance.fetchManagedStudies();
  }

  void _reload() =>
      setState(() => studies = ApiClient.instance.fetchManagedStudies());

  Future<void> _open(ManagedStudy study) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudyManagePage(studyId: study.id, title: study.title),
      ),
    );
    // 출석·과제를 바꾸고 돌아오면 목록의 수치도 갱신한다.
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.member.role == MemberRole.admin;
    return PageFrame(
      key: const ValueKey('manage'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            eyebrow: 'STUDY MANAGEMENT',
            title: '스터디 관리',
            subtitle: isAdmin
                ? '운영진은 모든 스터디의 참여자, 출석, 과제를 관리할 수 있습니다.'
                : '담당하는 스터디의 참여자, 출석, 과제를 관리합니다.',
          ),
          const SizedBox(height: 28),
          FutureBuilder<List<ManagedStudy>>(
            future: studies,
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
              final all = snapshot.data ?? const <ManagedStudy>[];
              if (all.isEmpty) {
                return const WideEmptyState(
                  message: '관리할 스터디가 없습니다. 스터디장 지정은 운영진에게 문의해주세요.',
                );
              }
              final semesters =
                  {for (final study in all) study.semester}.toList();
              final selected = semesters.contains(semester) ? semester : null;
              final visible = selected == null
                  ? all
                  : all.where((study) => study.semester == selected).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (semesters.length > 1) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('전체'),
                          selected: selected == null,
                          onSelected: (_) => setState(() => semester = null),
                        ),
                        for (final name in semesters)
                          ChoiceChip(
                            label: Text(name),
                            selected: selected == name,
                            onSelected: (_) => setState(() => semester = name),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 900
                          ? 3
                          : constraints.maxWidth >= 580
                              ? 2
                              : 1;
                      final width =
                          ((constraints.maxWidth - 16 * (columns - 1)) /
                                  columns)
                              .floorToDouble();
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          for (final study in visible)
                            SizedBox(
                              width: width,
                              child: _ManagedStudyCard(
                                study: study,
                                onTap: () => _open(study),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ManagedStudyCard extends StatelessWidget {
  const _ManagedStudyCard({required this.study, required this.onTap});
  final ManagedStudy study;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    StatusBadge(label: study.semester),
                    if (study.uncheckedCount > 0)
                      StatusBadge(
                        label: '미확인 제출 ${study.uncheckedCount}',
                        tone: BadgeTone.danger,
                        icon: Icons.mark_email_unread_outlined,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  study.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '스터디장 · ${study.leaderName}',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    IconStat(
                      icon: Icons.group_outlined,
                      label: '참여자 ${study.participantCount}명',
                    ),
                    IconStat(
                      icon: Icons.event_available_outlined,
                      label: '회차 ${study.sessionCount}',
                    ),
                    IconStat(
                      icon: Icons.assignment_outlined,
                      label: '과제 ${study.assignmentCount}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}
