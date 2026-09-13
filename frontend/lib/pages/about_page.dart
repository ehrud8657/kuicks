import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';

/// 운영진 한 명. 학과와 (있다면) 직책을 함께 보여준다.
class _Staff {
  const _Staff({required this.name, required this.department, this.role});
  final String name;
  final String department;
  final String? role;
}

/// 운영진 부서 하나.
class _StaffGroup {
  const _StaffGroup({required this.name, required this.members});
  final String name;
  final List<_Staff> members;
}

// 운영진 명단은 학기마다 바뀌므로, 자주 갱신하게 되면 DB로 옮기는 편이 낫다.
const _staffGroups = <_StaffGroup>[
  _StaffGroup(
    name: '회장단',
    members: [
      _Staff(role: '회장', name: '배세강', department: '컴퓨터학과'),
      _Staff(role: '부회장', name: '김한성', department: '컴퓨터학과'),
    ],
  ),
  _StaffGroup(
    name: '교육부',
    members: [
      _Staff(name: '강근호', department: '컴퓨터학과'),
      _Staff(name: '이건하', department: '컴퓨터학과'),
      _Staff(name: '신채민', department: '컴퓨터학과'),
      _Staff(name: '이호준', department: '컴퓨터학과'),
    ],
  ),
  _StaffGroup(
    name: '총무부',
    members: [
      _Staff(name: '김두호', department: '컴퓨터학과'),
      _Staff(name: '김정인', department: '컴퓨터학과'),
      _Staff(name: '신채민', department: '컴퓨터학과'),
      _Staff(name: '박유진', department: '컴퓨터학과'),
      _Staff(name: '진유진', department: '컴퓨터학과'),
      _Staff(name: '한도경', department: '컴퓨터학과'),
    ],
  ),
];

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) => PageFrame(
        key: const ValueKey('about'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ABOUT',
              style: TextStyle(
                color: AppColors.crimson,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'KUICS를 소개합니다',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            const Text(
              'KUICS는 2005년 1월 11일에 설립된 고려대학교 정보대학 소속 '
              '정보보호동아리입니다. KUICS는 정보보호와 보안에 대한 학구적 탐구심, '
              '올바른 윤리의식을 바탕으로 해킹사고 대응을 위해 다양한 보안기술과 '
              '해킹, 방어기법을 연구하고 있습니다.',
              style: TextStyle(
                fontSize: 17,
                height: 1.7,
                color: AppColors.textBody,
              ),
            ),
            const SizedBox(height: 44),
            const Text(
              '운영진',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24),
            ),
            const SizedBox(height: 18),
            for (final group in _staffGroups)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _StaffGroupCard(group: group),
              ),
          ],
        ),
      );
}

class _StaffGroupCard extends StatelessWidget {
  const _StaffGroupCard({required this.group});
  final _StaffGroup group;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    group.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${group.members.length}명',
                    style: const TextStyle(color: AppColors.textSubtle),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final member in group.members)
                    _StaffChip(member: member),
                ],
              ),
            ],
          ),
        ),
      );
}

class _StaffChip extends StatelessWidget {
  const _StaffChip({required this.member});
  final _Staff member;

  @override
  Widget build(BuildContext context) {
    final role = member.role;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (role != null) ...[
            Text(
              role,
              style: const TextStyle(
                color: AppColors.crimson,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
          ],
          Text(
            member.name,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 2),
          Text(
            member.department,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
