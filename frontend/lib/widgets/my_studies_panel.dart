import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api_client.dart';
import '../models.dart';
import '../routes.dart';
import '../theme.dart';
import 'common.dart';

/// 로그인 회원의 수강 중인 스터디 바로가기. 홈과 Study 메뉴 위쪽에 둔다.
///
/// 마이페이지 안쪽까지 들어가지 않아도 스터디 상세(게시판·과제 제출)로 바로 가게 한다.
/// 수강 중인 스터디가 없거나 불러오지 못하면 아무것도 그리지 않는다(공개 화면을 가리지 않게).
class MyStudiesPanel extends StatefulWidget {
  const MyStudiesPanel({super.key, this.margin = EdgeInsets.zero});

  /// 바깥 여백. 보여줄 스터디가 있을 때만 붙어, 없을 때 빈 간격이 남지 않는다.
  final EdgeInsetsGeometry margin;

  @override
  State<MyStudiesPanel> createState() => _MyStudiesPanelState();
}

class _MyStudiesPanelState extends State<MyStudiesPanel> {
  late final Future<List<MyStudy>> studies =
      ApiClient.instance.fetchMyStudies();

  @override
  Widget build(BuildContext context) => FutureBuilder<List<MyStudy>>(
        future: studies,
        builder: (context, snapshot) {
          final ongoing = (snapshot.data ?? const <MyStudy>[])
              .where((study) => study.isOngoing)
              .toList();
          if (ongoing.isEmpty) return const SizedBox.shrink();
          final pending = ongoing.fold<int>(
            0,
            (sum, study) => sum + study.pendingAssignmentCount,
          );
          return Container(
            width: double.infinity,
            margin: widget.margin,
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14071B33),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.menu_book_outlined,
                        size: 20,
                        color: AppColors.crimson,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          pending > 0
                              ? '수강 중인 스터디 · 제출할 과제 $pending개'
                              : '수강 중인 스터디',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                for (final study in ongoing)
                  InkWell(
                    // push로 열어 상세의 ← 버튼이 지금 화면으로 돌아오게 한다.
                    onTap: () => GoRouter.maybeOf(context)
                        ?.push(AppRoutes.myStudy(study.studyId)),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${study.title} · ${study.semester}',
                              style: const TextStyle(
                                color: AppColors.textBody,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (study.pendingAssignmentCount > 0) ...[
                            const SizedBox(width: 8),
                            StatusBadge(
                              label: '과제 ${study.pendingAssignmentCount}',
                              tone: BadgeTone.danger,
                            ),
                          ],
                          const Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: AppColors.textSubtle,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
}
