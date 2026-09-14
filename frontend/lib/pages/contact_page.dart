import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import '../widgets/common.dart';

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  static const _instagramId = '@kuics.official';
  static const _instagramUrl = 'https://www.instagram.com/kuics.official/';
  static const _email = 'kuicsofficial@gmail.com';

  @override
  Widget build(BuildContext context) => const PageFrame(
        key: ValueKey('contact'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              eyebrow: 'CONTACT',
              title: 'KUICS와 연결하기',
              subtitle: '공식 채널에서 KUICS의 소식을 받아보세요.',
            ),
            SizedBox(height: 28),
            _ContactCard(
              icon: Icons.photo_camera_outlined,
              label: 'Instagram',
              value: _instagramId,
              url: _instagramUrl,
            ),
            SizedBox(height: 12),
            _ContactCard(
              icon: Icons.mail_outline,
              label: '이메일',
              value: _email,
              // mailto:는 기본 메일 앱이나 웹메일을 연다.
              url: 'mailto:$_email',
            ),
          ],
        ),
      );
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.url,
  });

  final IconData icon;
  final String label;
  final String value;
  final String url;

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri)) {
      messenger.showSnackBar(
        SnackBar(content: Text('열지 못했습니다: $value')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                IconBadge(icon: icon),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceMuted,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_outward,
                    size: 18,
                    color: AppColors.crimson,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
