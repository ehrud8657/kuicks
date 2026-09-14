import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kuics_frontend/api_client.dart';
import 'package:kuics_frontend/main.dart';
import 'package:kuics_frontend/pages/manage/study_manage_page.dart';
import 'package:kuics_frontend/widgets/auth_dialogs.dart';

import 'support/fake_backend.dart';
import 'support/fixtures.dart';

/// 주소로 바로 들어오기, ← 버튼으로 부모 화면 돌아가기, 권한 안내를 확인한다.
void main() {
  late FakeBackend backend;

  setUp(() {
    backend = FakeBackend()..install();
    registerManageRoutes(backend);
  });

  tearDown(() => ApiClient.instance = ApiClient());

  Future<void> open(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(KuicsApp(initialLocation: location));
    await tester.pumpAndSettle();
  }

  String pathOf(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(Navigator).first))
          .state
          .uri
          .toString();

  Finder cardOf(String name) =>
      find.ancestor(of: find.text(name), matching: find.byType(Card)).first;

  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
  }

  testWidgets('출석 체크 주소로 바로 들어와도 ← 버튼이 출석 탭 → 관리 목록으로 돌아간다', (tester) async {
    await open(tester, '/manage/studies/1/attendance/22');
    expect(find.text('미기록 모두 출석'), findsOneWidget);
    expect(find.text('2회차 출석 체크'), findsOneWidget);

    await back(tester);
    expect(pathOf(tester), '/manage/studies/1/attendance');
    expect(find.text('회차별 출석 체크'), findsOneWidget);

    await back(tester);
    expect(pathOf(tester), '/manage');
    expect(find.text('STUDY MANAGEMENT'), findsOneWidget);
  });

  testWidgets('스터디 주소는 참여자 탭으로 보내고, 탭을 바꾸면 주소도 바뀐다', (tester) async {
    await open(tester, '/manage/studies/1');
    expect(pathOf(tester), '/manage/studies/1/participants');
    expect(find.text('참여자 3명 · 중도 포기 1명'), findsOneWidget);

    await tester.tap(find.text('과제'));
    await tester.pumpAndSettle();
    expect(pathOf(tester), '/manage/studies/1/assignments');
    expect(find.text('XSS 필터 우회'), findsOneWidget);
    // 탭을 바꿔도 화면을 새로 만들지 않아 스터디를 다시 불러오지 않는다.
    expect(backend.sent('GET', '/api/manage/studies/1/'), hasLength(1));
    expect(find.byType(StudyManagePage), findsOneWidget);

    // 탭 이동은 방문 기록을 늘리지 않으므로 ← 한 번에 목록으로 간다.
    await back(tester);
    expect(pathOf(tester), '/manage');
  });

  testWidgets('저장하지 않은 출석이 있으면 나가기 전에 확인한다', (tester) async {
    await open(tester, '/manage/studies/1/attendance/22');
    await tester.tap(
      find.descendant(of: cardOf('박철수'), matching: find.text('출석')),
    );
    await tester.pump();

    await back(tester);
    expect(find.text('저장하지 않고 나가기'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(pathOf(tester), '/manage/studies/1/attendance/22');

    await back(tester);
    await tester.tap(find.text('나가기'));
    await tester.pumpAndSettle();
    expect(pathOf(tester), '/manage/studies/1/attendance');
    expect(backend.sent('PUT', '/api/manage/sessions/22/attendance/'), isEmpty);
  });

  testWidgets('로그인하지 않고 /me에 들어오면 로그인 안내를 보여준다', (tester) async {
    backend.on(
      'GET',
      '/api/me/',
      (_) => <String, dynamic>{
        'code': 'not_authenticated',
        'message': ApiClient.loginRequiredMessage,
        'fields': null,
      },
      status: 403,
    );
    await open(tester, '/me');
    expect(find.text('로그인이 필요합니다'), findsOneWidget);
    expect(find.byType(LoginDialog), findsNothing);
  });

  testWidgets('정회원이 /manage에 들어오면 볼 수 없다는 안내만 보여준다', (tester) async {
    backend.on('GET', '/api/me/', (_) => memberJson(role: 'member'));
    await open(tester, '/manage/studies/1/participants');
    expect(find.text('볼 수 없는 페이지입니다'), findsOneWidget);
    expect(backend.sent('GET', '/api/manage/studies/1/'), isEmpty);
  });

  testWidgets('없는 주소는 안내 화면을 보여준다', (tester) async {
    await open(tester, '/nope');
    expect(find.text('페이지를 찾을 수 없습니다'), findsOneWidget);

    await open(tester, '/manage/studies/abc/participants');
    expect(find.text('페이지를 찾을 수 없습니다'), findsOneWidget);
  });

  testWidgets('끝에 붙은 / 는 떼고, 게시판 분류는 주소를 따른다', (tester) async {
    await open(tester, '/board/?category=recruit');
    expect(pathOf(tester), '/board?category=recruit');
    expect(backend.sent('GET', '/api/boards/').last.url.queryParameters, {
      'category': 'recruit',
    });

    await tester.tap(find.widgetWithText(ChoiceChip, '전체'));
    await tester.pumpAndSettle();
    expect(pathOf(tester), '/board');
  });

  testWidgets('로그인이 풀린 채 API를 부르면 안내 문구와 함께 로그인 창을 띄운다', (tester) async {
    await open(tester, '/');
    backend.on(
      'GET',
      '/api/manage/studies/',
      (_) => <String, dynamic>{
        'code': 'not_authenticated',
        'message': '자격 인증데이터가 제공되지 않았습니다.',
        'fields': null,
      },
      status: 403,
    );
    GoRouter.of(tester.element(find.byType(Navigator).first)).go('/manage');
    await tester.pumpAndSettle();

    expect(find.byType(LoginDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(LoginDialog),
        matching: find.text(ApiClient.loginRequiredMessage),
      ),
      findsOneWidget,
    );
    // 로그인 창 뒤의 화면은 로그인 안내로 바뀐다.
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.text('로그인이 필요합니다'), findsOneWidget);
  });
}
