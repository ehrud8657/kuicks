import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuics_frontend/api_client.dart';
import 'package:kuics_frontend/main.dart';
import 'package:kuics_frontend/pages/manage/attendance_page.dart';
import 'package:kuics_frontend/pages/manage/forms.dart';
import 'package:kuics_frontend/pages/manage/study_manage_page.dart';
import 'package:kuics_frontend/pages/manage/submissions_page.dart';

import 'support/fake_backend.dart';
import 'support/fixtures.dart';

void main() {
  late FakeBackend backend;

  setUp(() {
    backend = FakeBackend()..install();
    registerManageRoutes(backend);
  });

  tearDown(() => ApiClient.instance = ApiClient());

  void setScreen(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Finder cardOf(String name) =>
      find.ancestor(of: find.text(name), matching: find.byType(Card)).first;

  group('등급에 따라 달라지는 화면', () {
    testWidgets('스터디장은 상단 메뉴와 홈에 스터디 관리가 보인다', (tester) async {
      setScreen(tester, const Size(1600, 1000));
      await tester.pumpWidget(const KuicsApp());
      await tester.pumpAndSettle();

      // 상단 메뉴 버튼 + 홈의 관리 바로가기 버튼
      expect(find.text('스터디 관리'), findsNWidgets(2));
      expect(find.text('스터디장 메뉴'), findsOneWidget);
      expect(find.text('담당 스터디 1개'), findsOneWidget);
      expect(find.text('· 미확인 제출물 1건'), findsOneWidget);
    });

    testWidgets('정회원에게는 스터디 관리가 보이지 않고 관리 API도 부르지 않는다', (tester) async {
      backend.on(
        'GET',
        '/api/me/',
        (_) => memberJson(role: 'member', name: '홍길동'),
      );
      setScreen(tester, const Size(1600, 1000));
      await tester.pumpWidget(const KuicsApp());
      await tester.pumpAndSettle();

      expect(find.text('스터디 관리'), findsNothing);
      expect(backend.sent('GET', '/api/manage/studies/'), isEmpty);
    });

    testWidgets('휴대폰 폭에서는 메뉴 서랍에서 스터디 관리로 들어간다', (tester) async {
      setScreen(tester, const Size(390, 844));
      await tester.pumpWidget(const KuicsApp());
      await tester.pumpAndSettle();

      expect(find.text('스터디장 메뉴'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, '스터디 관리'));
      await tester.pumpAndSettle();

      expect(find.text('STUDY MANAGEMENT'), findsOneWidget);
      expect(find.text('[예시] 웹해킹 입문'), findsOneWidget);
    });
  });

  testWidgets('담당 스터디를 열어 참여자·출석·과제 탭을 오간다', (tester) async {
    setScreen(tester, const Size(1280, 900));
    await tester.pumpWidget(const KuicsApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('스터디 관리').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('[예시] 웹해킹 입문'));
    await tester.pumpAndSettle();

    expect(find.text('참여자 3명 · 중도 포기 1명'), findsOneWidget);
    expect(find.text('홍길동'), findsOneWidget);

    await tester.tap(find.text('출석'));
    await tester.pumpAndSettle();
    expect(find.text('회차별 출석 체크'), findsOneWidget);
    expect(find.text('SQL Injection'), findsOneWidget);
    expect(find.text('정민지 (포기)'), findsOneWidget);

    await tester.tap(find.text('과제'));
    await tester.pumpAndSettle();
    expect(find.text('XSS 필터 우회'), findsOneWidget);
    expect(find.text('미제출 3'), findsOneWidget);
  });

  group('출석 체크', () {
    testWidgets('상태와 한글 메모를 저장한다', (tester) async {
      setScreen(tester, const Size(390, 844));
      await tester.pumpWidget(
        testApp(const AttendancePage(sessionId: 22, title: '2회차 출석 체크')),
      );
      await tester.pumpAndSettle();

      final card = cardOf('홍길동');
      await tester.tap(find.descendant(of: card, matching: find.text('지각')));
      await tester.enterText(
        find.descendant(of: card, matching: find.byType(TextField)),
        '버스 지연으로 10분 늦음',
      );
      await tester.pump();
      expect(find.text('저장하지 않은 변경 사항이 있습니다.'), findsOneWidget);

      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      final records = {
        for (final record in backend.lastJson(
            'PUT', '/api/manage/sessions/22/attendance/')['records'] as List)
          (record as Map<String, dynamic>)['participation_id']: record,
      };
      expect(records[11], {
        'participation_id': 11,
        'status': 'late',
        'note': '버스 지연으로 10분 늦음',
      });
      expect(records[12]!['status'], isNull);
      expect(find.text('출석을 저장했습니다.'), findsOneWidget);
      expect(find.text('변경 사항이 모두 저장되었습니다.'), findsOneWidget);
    });

    testWidgets('미기록 모두 출석은 이미 고른 상태를 덮어쓰지 않는다', (tester) async {
      setScreen(tester, const Size(1280, 900));
      await tester.pumpWidget(
        testApp(const AttendancePage(sessionId: 22, title: '2회차 출석 체크')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(of: cardOf('홍길동'), matching: find.text('결석')),
      );
      await tester.tap(find.text('미기록 모두 출석'));
      await tester.pump();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      final statuses = {
        for (final record in backend.lastJson(
            'PUT', '/api/manage/sessions/22/attendance/')['records'] as List)
          (record as Map<String, dynamic>)['participation_id']:
              record['status'],
      };
      expect(statuses, {11: 'absent', 12: 'present', 13: 'present'});
    });

    testWidgets('저장하지 않고 뒤로 가면 확인을 받는다', (tester) async {
      setScreen(tester, const Size(1280, 900));
      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const AttendancePage(sessionId: 22, title: '2회차 출석 체크'),
                  ),
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: cardOf('박철수'), matching: find.text('출석')),
      );
      await tester.pump();

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('저장하지 않고 나가기'), findsOneWidget);

      await tester.tap(find.text('나가기'));
      await tester.pumpAndSettle();
      expect(find.text('열기'), findsOneWidget);
      expect(
          backend.sent('PUT', '/api/manage/sessions/22/attendance/'), isEmpty);
    });
  });

  testWidgets('과제 등록: 제목이 비면 막고 한글 제목과 기한을 보낸다', (tester) async {
    setScreen(tester, const Size(1280, 900));
    await tester.pumpWidget(
      testApp(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const AssignmentFormDialog(studyId: 1),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('제목을 입력해주세요.'), findsOneWidget);
    expect(backend.sent('POST', '/api/manage/studies/1/assignments/'), isEmpty);

    await tester.enterText(
      find.widgetWithText(TextFormField, '제목'),
      'CSRF 토큰 분석 과제',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '설명 (선택)'),
      '첫 줄\n둘째 줄 https://owasp.org',
    );
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    final body = backend.lastJson('POST', '/api/manage/studies/1/assignments/');
    expect(body['title'], 'CSRF 토큰 분석 과제');
    expect(body['description'], '첫 줄\n둘째 줄 https://owasp.org');
    final due = DateTime.parse(body['due_at'] as String).toLocal();
    expect((due.hour, due.minute), (23, 59));
    expect(due.isAfter(DateTime.now()), isTrue);
    expect(find.byType(AssignmentFormDialog), findsNothing);
  });

  testWidgets('제출 현황: 미제출 필터와 확인 처리', (tester) async {
    setScreen(tester, const Size(1280, 900));
    await tester.pumpWidget(
      testApp(
        const SubmissionsPage(assignmentId: 31, title: 'SQL Injection 실습 보고서'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('홍길동_SQLi.zip'), findsOneWidget);
    expect(find.text('필터 우회 과정을 잘 정리했어요.'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '미제출 1'));
    await tester.pumpAndSettle();
    expect(find.text('박철수'), findsOneWidget);
    expect(find.text('홍길동'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, '지각 제출 1'));
    await tester.pumpAndSettle();
    expect(find.text('이영희'), findsOneWidget);

    await tester.tap(find.text('확인 전'));
    await tester.pumpAndSettle();
    expect(
      backend.lastJson('PATCH', '/api/manage/submissions/42/'),
      {'review_status': 'checked'},
    );
    // 저장 뒤 다시 불러오는 과정에서 오류가 나면 실패 안내가 뜬다.
    expect(find.text('확인 상태를 바꾸지 못했습니다.'), findsNothing);
    expect(backend.sent('GET', '/api/manage/assignments/31/submissions/'),
        hasLength(2));
  });

  testWidgets('휴대폰 폭(360)에서도 관리 화면들이 넘치지 않는다', (tester) async {
    setScreen(tester, const Size(360, 740));

    await tester.pumpWidget(
      testApp(const StudyManagePage(studyId: 1, title: '[예시] 웹해킹 입문')),
    );
    await tester.pumpAndSettle();
    for (final tab in ['출석', '과제', '참여자']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(
      testApp(
        const SubmissionsPage(assignmentId: 31, title: 'SQL Injection 실습 보고서'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      testApp(const AttendancePage(sessionId: 22, title: '2회차 출석 체크')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
