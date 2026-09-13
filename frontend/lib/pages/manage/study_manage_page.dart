import 'package:flutter/material.dart';

import '../../api_client.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'assignments_tab.dart';
import 'attendance_tab.dart';
import 'participants_tab.dart';

/// 스터디 하나의 관리 화면. 참여자 / 출석 / 과제 탭으로 나눈다.
class StudyManagePage extends StatefulWidget {
  const StudyManagePage({
    super.key,
    required this.studyId,
    required this.title,
  });

  final int studyId;
  final String title;

  @override
  State<StudyManagePage> createState() => _StudyManagePageState();
}

class _StudyManagePageState extends State<StudyManagePage> {
  late Future<ManagedStudyDetail> detail;

  @override
  void initState() {
    super.initState();
    detail = ApiClient.instance.fetchManagedStudy(widget.studyId);
  }

  void _reload() => setState(
        () => detail = ApiClient.instance.fetchManagedStudy(widget.studyId),
      );

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: detailAppBar(
            widget.title,
            bottom: const TabBar(
              labelColor: AppColors.crimson,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.crimson,
              labelStyle: TextStyle(fontWeight: FontWeight.w700),
              tabs: [
                Tab(icon: Icon(Icons.group_outlined), text: '참여자'),
                Tab(icon: Icon(Icons.event_available_outlined), text: '출석'),
                Tab(icon: Icon(Icons.assignment_outlined), text: '과제'),
              ],
            ),
          ),
          body: FutureBuilder<ManagedStudyDetail>(
            future: detail,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return CenteredListView(
                  children: [
                    LoadError(
                      onRetry: _reload,
                      message: errorMessageOf(snapshot.error),
                    ),
                  ],
                );
              }
              final data = snapshot.data;
              if (data == null) return const LoadingView();
              // 새로 불러오는 동안에도 기존 내용을 그대로 두고 위쪽에만 진행 표시를 한다.
              final refreshing =
                  snapshot.connectionState == ConnectionState.waiting;
              return Column(
                children: [
                  SizedBox(
                    height: 3,
                    child: refreshing ? const LinearProgressIndicator() : null,
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        ParticipantsTab(detail: data, onChanged: _reload),
                        AttendanceTab(detail: data, onChanged: _reload),
                        AssignmentsTab(detail: data, onChanged: _reload),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
}
