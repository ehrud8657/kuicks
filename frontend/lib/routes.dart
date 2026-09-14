import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'models.dart';

/// 스터디 관리 화면의 탭. 이름이 그대로 주소 조각이 된다. 예: /manage/studies/3/attendance
enum ManageTab {
  participants,
  attendance,
  assignments;

  static ManageTab? tryParse(String? name) {
    for (final tab in values) {
      if (tab.name == name) return tab;
    }
    return null;
  }
}

/// 사이트의 모든 주소. 화면을 열 때는 문자열을 직접 쓰지 말고 여기를 거친다.
///
/// `/api`, `/admin`, `/static`, `/media`는 백엔드로 넘어가는 주소라 화면 경로로 쓰지 않는다.
class AppRoutes {
  const AppRoutes._();

  static const home = '/';
  static const about = '/about';
  static const study = '/study';
  static const activity = '/activity';
  static const board = '/board';
  static const contact = '/contact';
  static const me = '/me';
  static const manage = '/manage';

  /// 학기 선택을 주소에 남긴다. 예: /study?semester=2026-2
  static String studyOf(String? semester) => semester == null
      ? study
      : Uri(path: study, queryParameters: {'semester': semester}).toString();

  /// 게시판 분류를 주소에 남긴다. 예: /board?category=notice
  static String boardOf(PostCategory? category) =>
      category == null ? board : '$board?category=${category.name}';

  /// 참여자 본인의 스터디 상세.
  static String myStudy(int studyId) => '$me/studies/$studyId';

  /// 스터디 관리 화면의 탭.
  static String manageStudy(
    int studyId, [
    ManageTab tab = ManageTab.participants,
  ]) =>
      '$manage/studies/$studyId/${tab.name}';

  /// 회차 하나의 출석 체크.
  static String attendance(int studyId, int sessionId) =>
      '${manageStudy(studyId, ManageTab.attendance)}/$sessionId';

  /// 과제 하나의 제출 현황.
  static String submissions(int studyId, int assignmentId) =>
      '${manageStudy(studyId, ManageTab.assignments)}/$assignmentId';
}

/// 탭·학기·분류처럼 같은 화면 안의 선택을 주소에 반영한다.
/// 브라우저 방문 기록은 늘리지 않는다 (뒤로가기가 선택 하나하나를 되돌리지 않게).
/// 라우터 없이 띄운 화면(위젯 테스트 등)에서는 아무것도 하지 않는다.
void replaceLocation(BuildContext context, String location) {
  final router = GoRouter.maybeOf(context);
  if (router == null) return;
  Router.neglect(context, () => router.replace<void>(location));
}
