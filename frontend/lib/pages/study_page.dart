import 'package:flutter/material.dart';

import '../api_client.dart';
import '../models.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/common.dart';

class StudyPage extends StatefulWidget {
  const StudyPage({super.key, this.semester});

  /// 주소의 ?semester= 값. 없거나 없는 학기면 최신 학기를 보여준다.
  final String? semester;
  @override
  State<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage> {
  late Future<List<Semester>> semesters;

  /// 주소를 바꿀 수 없는 환경(테스트 등)에서 고른 학기.
  String? _picked;

  @override
  void initState() {
    super.initState();
    semesters = ApiClient.instance.fetchSemesters();
  }

  @override
  void didUpdateWidget(StudyPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.semester != oldWidget.semester) _picked = null;
  }

  int _selectedIndex(List<Semester> data) {
    final name = _picked ?? widget.semester;
    final index = name == null ? -1 : data.indexWhere((s) => s.name == name);
    return index < 0 ? 0 : index;
  }

  /// 학기 선택을 주소에 남기되 방문 기록은 늘리지 않는다.
  void _select(Semester semester) {
    setState(() => _picked = semester.name);
    replaceLocation(context, AppRoutes.studyOf(semester.name));
  }

  @override
  Widget build(BuildContext context) => PageFrame(
        key: const ValueKey('study'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageHeader(
              eyebrow: 'STUDY',
              title: '함께 배우는 KUICS 스터디',
              subtitle: '학기를 선택하고 스터디별 커리큘럼과 수료자를 확인하세요.',
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
                  return LoadError(
                    onRetry: () => setState(() {
                      semesters = ApiClient.instance.fetchSemesters();
                    }),
                  );
                }
                final data = snapshot.data ?? const [];
                if (data.isEmpty) return const EmptyState();
                final selected = _selectedIndex(data);
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
                          onSelected: (_) => _select(data[index]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (data[selected].studies.isEmpty)
                      const EmptyState(message: '이 학기에 등록된 스터디가 없습니다.')
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
    // 동명이인 구분을 위해 수료자 명단은 이름에 학번 뒷 2자리를 붙여 표기한다.
    final completed = study.participants
        .where((p) => p.status == ParticipationStatus.completed)
        .map((p) => p.label)
        .toList();
    final excellent = study.participants
        .where((p) => p.status == ParticipationStatus.excellent)
        .map((p) => p.label)
        .toList();
    return SoftCard(
      accent: true,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
        title: Text(
          study.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '스터디장 · ${study.leader}',
          style: const TextStyle(color: AppColors.textMuted),
        ),
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
              child: Text(label,
                  style: const TextStyle(color: AppColors.textMuted)),
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
                color: accent ? AppColors.crimson : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              names.isEmpty ? '없음' : names.join(', '),
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      );
}
