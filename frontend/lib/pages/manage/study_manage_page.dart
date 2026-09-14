import 'package:flutter/material.dart';

import '../../api_client.dart';
import '../../models.dart';
import '../../routes.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/refresh_on_return.dart';
import 'assignments_tab.dart';
import 'attendance_tab.dart';
import 'participants_tab.dart';

/// 스터디 하나의 관리 화면. 참여자 / 출석 / 과제 탭으로 나누고, 탭은 주소에 남긴다.
/// 예: /manage/studies/3/attendance
class StudyManagePage extends StatefulWidget {
  const StudyManagePage({
    super.key,
    required this.studyId,
    this.tab = ManageTab.participants,
    this.title,
  });

  final int studyId;
  final ManageTab tab;

  /// 불러오기 전에 상단바에 잠깐 보여줄 제목.
  final String? title;

  @override
  State<StudyManagePage> createState() => _StudyManagePageState();
}

class _StudyManagePageState extends State<StudyManagePage>
    with SingleTickerProviderStateMixin, RefreshOnReturn {
  late Future<ManagedStudyDetail> detail;
  late final TabController tabs = TabController(
    length: ManageTab.values.length,
    vsync: this,
    initialIndex: widget.tab.index,
  )..addListener(_onTabChanged);
  String? _title;

  @override
  void initState() {
    super.initState();
    detail = _fetch();
  }

  Future<ManagedStudyDetail> _fetch() {
    final future = ApiClient.instance.fetchManagedStudy(widget.studyId);
    future.then(
      (data) {
        if (mounted && _title != data.title) {
          setState(() => _title = data.title);
        }
      },
      onError: (_) {},
    );
    return future;
  }

  void _reload() => setState(() {
        detail = _fetch();
      });

  @override
  void didUpdateWidget(StudyManagePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 주소가 바뀌어(브라우저 뒤로가기 등) 탭이 달라지면 화면 탭도 맞춘다.
    if (widget.tab.index != tabs.index) tabs.animateTo(widget.tab.index);
  }

  /// 탭을 누르거나 밀어서 바꾸면 주소만 바꾸고 방문 기록은 늘리지 않는다.
  void _onTabChanged() {
    if (tabs.indexIsChanging) return;
    final tab = ManageTab.values[tabs.index];
    if (tab == widget.tab) return;
    replaceLocation(context, AppRoutes.manageStudy(widget.studyId, tab));
  }

  // 출석 체크·제출 현황에서 돌아오면 수치를 다시 불러온다.
  @override
  bool isOwnPath(String path) => ManageTab.values
      .any((tab) => path == AppRoutes.manageStudy(widget.studyId, tab));

  @override
  void onReturn() => _reload();

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: detailAppBar(
          _title ?? widget.title ?? '스터디 관리',
          bottom: TabBar(
            controller: tabs,
            labelColor: AppColors.crimson,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.crimson,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            tabs: const [
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
                    controller: tabs,
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
      );
}
