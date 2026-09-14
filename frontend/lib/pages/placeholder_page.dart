import 'package:flutter/material.dart';

import '../app_shell.dart';
import '../theme.dart';
import '../widgets/common.dart';

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.page});
  final SitePage page;
  @override
  Widget build(BuildContext context) {
    final content = switch (page) {
      SitePage.activity => (
          'ACTIVITY',
          '우리의 활동 기록',
          'CTF, 대회, 프로젝트 기록을 보여줄 공간입니다.',
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
              color: AppColors.crimson,
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
