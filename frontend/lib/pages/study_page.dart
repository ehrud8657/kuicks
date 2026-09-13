import 'package:flutter/material.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

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
                color: AppColors.crimson,
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
              style: TextStyle(color: AppColors.textMuted),
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
                    onRetry: () => setState(
                        () => semesters = ApiClient().fetchSemesters()),
                  );
                }
                final data = snapshot.data ?? const [];
                if (data.isEmpty) return const EmptyState();
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
