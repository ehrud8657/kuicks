import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';

/// 아직 내용이 준비되지 않은 메뉴.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.message,
  });

  const PlaceholderPage.activity({super.key})
      : eyebrow = 'ACTIVITY',
        title = '우리의 활동 기록',
        message = 'CTF, 대회, 프로젝트 기록을 보여줄 공간입니다.';

  final String eyebrow;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => PageFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: const TextStyle(
                color: AppColors.crimson,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 28),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(message),
              ),
            ),
          ],
        ),
      );
}
