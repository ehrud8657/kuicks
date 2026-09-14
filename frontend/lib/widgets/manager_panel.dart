import 'package:flutter/material.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import 'common.dart';

/// 스터디장·운영진에게만 보이는 관리 바로가기. 홈과 마이페이지 위쪽에 둔다.
class ManagerPanel extends StatefulWidget {
  const ManagerPanel({super.key, required this.member, required this.onManage});
  final Member member;
  final VoidCallback onManage;

  @override
  State<ManagerPanel> createState() => _ManagerPanelState();
}

class _ManagerPanelState extends State<ManagerPanel> {
  late final Future<List<ManagedStudy>> studies =
      ApiClient.instance.fetchManagedStudies();

  /// 요약 문장 조각. 좁은 화면에서는 조각 단위로 줄을 바꿔 단어 중간에서 끊기지 않게 한다.
  List<String> _summary(AsyncSnapshot<List<ManagedStudy>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const ['담당 스터디를 불러오는 중…'];
    }
    if (snapshot.hasError) {
      return [
        errorMessageOf(snapshot.error, fallback: '담당 스터디를 불러오지 못했습니다.'),
      ];
    }
    final list = snapshot.data ?? const <ManagedStudy>[];
    if (list.isEmpty) return const ['관리할 스터디가 없습니다.'];
    final unchecked =
        list.fold<int>(0, (sum, study) => sum + study.uncheckedCount);
    final scope = widget.member.role == MemberRole.admin ? '전체 스터디' : '담당 스터디';
    return ['$scope ${list.length}개', '· 미확인 제출물 $unchecked건'];
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<ManagedStudy>>(
        future: studies,
        builder: (context, snapshot) => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.crimson.withValues(alpha: .22)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F071B33),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final info = Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.crimsonSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.dashboard_customize_outlined,
                      color: AppColors.crimson,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.member.role.label} 메뉴',
                          style: const TextStyle(
                            color: AppColors.crimson,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 6,
                          children: [
                            for (final part in _summary(snapshot))
                              Text(
                                part,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final button = FilledButton.icon(
                onPressed: widget.onManage,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('스터디 관리'),
              );
              if (constraints.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [info, const SizedBox(height: 14), button],
                );
              }
              return Row(
                children: [
                  Expanded(child: info),
                  const SizedBox(width: 16),
                  button,
                ],
              );
            },
          ),
        ),
      );
}
