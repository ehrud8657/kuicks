import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_shell.dart';
import 'models.dart';
import 'pages/about_page.dart';
import 'pages/board_page.dart';
import 'pages/contact_page.dart';
import 'pages/home_page.dart';
import 'pages/manage/attendance_page.dart';
import 'pages/manage/manage_page.dart';
import 'pages/manage/study_manage_page.dart';
import 'pages/manage/submissions_page.dart';
import 'pages/my_page.dart';
import 'pages/my_study_page.dart';
import 'pages/placeholder_page.dart';
import 'pages/study_page.dart';
import 'routes.dart';
import 'widgets/route_guards.dart';

/// 사이트 전체 경로.
///
/// - 상단 메뉴가 있는 화면(/, /study, /me, /manage …)은 [SiteShell] 안에서 바뀐다.
/// - 상세 화면(/me/studies/3, /manage/studies/3/attendance …)은 상단 메뉴 없이 위에 쌓이고,
///   부모 경로가 아래에 깔리므로 주소로 바로 들어와도 ← 버튼이 부모 화면으로 돌아간다.
GoRouter createRouter({
  required GlobalKey<NavigatorState> rootNavigatorKey,
  String initialLocation = AppRoutes.home,
}) {
  final shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

  Page<void> shellPage(GoRouterState state, Widget child) =>
      NoTransitionPage<void>(key: state.pageKey, child: child);

  int? idOf(GoRouterState state, String name) =>
      int.tryParse(state.pathParameters[name] ?? '');

  GoRoute manageTabRoute(ManageTab tab, {List<RouteBase> routes = const []}) =>
      GoRoute(
        path: 'studies/:studyId/${tab.name}',
        parentNavigatorKey: rootNavigatorKey,
        // 탭이 달라도 같은 화면으로 취급해, 탭을 바꿀 때 화면을 새로 만들지 않는다.
        pageBuilder: (context, state) {
          final studyId = idOf(state, 'studyId');
          return MaterialPage<void>(
            key: ValueKey('manage-study-$studyId'),
            child: studyId == null
                ? NotFoundPage(location: state.uri.toString())
                : RequireManager(
                    detail: true,
                    builder: (context, _) =>
                        StudyManagePage(studyId: studyId, tab: tab),
                  ),
          );
        },
        routes: routes,
      );

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    // 끝에 붙은 / 는 떼어 같은 화면으로 보낸다. 예: /study/ → /study
    redirect: (context, state) {
      final path = state.uri.path;
      if (path.length > 1 && path.endsWith('/')) {
        return state.uri
            .replace(path: path.substring(0, path.length - 1))
            .toString();
      }
      return null;
    },
    errorBuilder: (context, state) =>
        NotFoundPage(location: state.uri.toString()),
    routes: [
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) =>
            SiteShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (context, state) => shellPage(state, const HomePage()),
          ),
          GoRoute(
            path: AppRoutes.about,
            pageBuilder: (context, state) =>
                shellPage(state, const AboutPage()),
          ),
          GoRoute(
            path: AppRoutes.study,
            pageBuilder: (context, state) => shellPage(
              state,
              StudyPage(semester: state.uri.queryParameters['semester']),
            ),
          ),
          GoRoute(
            path: AppRoutes.activity,
            pageBuilder: (context, state) =>
                shellPage(state, const PlaceholderPage.activity()),
          ),
          GoRoute(
            path: AppRoutes.board,
            pageBuilder: (context, state) => shellPage(
              state,
              BoardPage(
                category: PostCategory.values
                    .where(
                        (c) => c.name == state.uri.queryParameters['category'])
                    .firstOrNull,
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.contact,
            pageBuilder: (context, state) =>
                shellPage(state, const ContactPage()),
          ),
          GoRoute(
            path: AppRoutes.me,
            pageBuilder: (context, state) => shellPage(
              state,
              RequireLogin(
                  builder: (context, member) => MyPage(member: member)),
            ),
            routes: [
              GoRoute(
                path: 'studies/:studyId',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) {
                  final studyId = idOf(state, 'studyId');
                  if (studyId == null) {
                    return NotFoundPage(location: state.uri.toString());
                  }
                  return RequireLogin(
                    detail: true,
                    builder: (context, _) => MyStudyPage(studyId: studyId),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.manage,
            pageBuilder: (context, state) => shellPage(
              state,
              RequireManager(
                  builder: (context, member) => ManagePage(member: member)),
            ),
            routes: [
              GoRoute(
                path: 'studies/:studyId',
                redirect: (context, state) {
                  final studyId = idOf(state, 'studyId');
                  return studyId == null
                      ? null
                      : AppRoutes.manageStudy(studyId);
                },
              ),
              manageTabRoute(ManageTab.participants),
              manageTabRoute(
                ManageTab.attendance,
                routes: [
                  GoRoute(
                    path: ':sessionId',
                    parentNavigatorKey: rootNavigatorKey,
                    // 앱의 ← 버튼, 브라우저 뒤로가기, 다른 메뉴 이동 모두 여기를 거친다.
                    onExit: (context, state) => AttendancePage.confirmLeave(),
                    builder: (context, state) {
                      final studyId = idOf(state, 'studyId');
                      final sessionId = idOf(state, 'sessionId');
                      if (studyId == null || sessionId == null) {
                        return NotFoundPage(location: state.uri.toString());
                      }
                      return RequireManager(
                        detail: true,
                        builder: (context, _) =>
                            AttendancePage(sessionId: sessionId),
                      );
                    },
                  ),
                ],
              ),
              manageTabRoute(
                ManageTab.assignments,
                routes: [
                  GoRoute(
                    path: ':assignmentId',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final assignmentId = idOf(state, 'assignmentId');
                      if (idOf(state, 'studyId') == null ||
                          assignmentId == null) {
                        return NotFoundPage(location: state.uri.toString());
                      }
                      return RequireManager(
                        detail: true,
                        builder: (context, _) =>
                            SubmissionsPage(assignmentId: assignmentId),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
