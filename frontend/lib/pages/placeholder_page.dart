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
    this.icon = Icons.auto_awesome_outlined,
  });

  const PlaceholderPage.activity({super.key})
      : eyebrow = 'ACTIVITY',
        title = '우리의 활동 기록',
        message = 'CTF, 대회, 프로젝트 기록을 보여줄 공간입니다.',
        icon = Icons.emoji_events_outlined;

  final String eyebrow;
  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => PageFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(eyebrow: eyebrow, title: title),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: Card(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                  child: Column(
                    children: [
                      IconBadge(icon: icon, size: 60),
                      const SizedBox(height: 18),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: AppColors.textBody,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const StatusBadge(label: '준비 중'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
