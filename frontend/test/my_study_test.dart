import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuics_frontend/api_client.dart';
import 'package:kuics_frontend/main.dart';
import 'package:kuics_frontend/pages/my_study_page.dart';
import 'package:kuics_frontend/widgets/zip_picker.dart';

import 'support/fake_backend.dart';
import 'support/fixtures.dart';

/// 'PK'로 시작하는 가짜 zip 내용.
const zipBytes = [0x50, 0x4B, 0x03, 0x04, 0x14, 0x00, 0x00];

void main() {
  late FakeBackend backend;

  setUp(() {
    backend = FakeBackend()..install();
    registerMemberRoutes(backend);
  });

  tearDown(() => ApiClient.instance = ApiClient());

  void setScreen(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpStudy(
    WidgetTester tester, {
    PickedZip? pick,
    Size size = const Size(1280, 2200),
  }) async {
    setScreen(tester, size);
    await tester.pumpWidget(
      testApp(
        MyStudyPage(
          studyId: 1,
          title: '[예시] 웹해킹 입문',
          pickZip: () async => pick,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder cardOf(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(Card)).first;

  testWidgets('과제별 제출 상태·피드백과 회차별 내 출석을 보여준다', (tester) async {
    await pumpStudy(tester);

    expect(find.text('아직 제출하지 않았습니다.'), findsOneWidget);
    expect(find.text('필터 우회 과정을 잘 정리했어요.'), findsOneWidget);
    expect(find.text('스터디장 확인 완료'), findsOneWidget);
    expect(find.text('출석 1'), findsOneWidget);
    expect(find.text('미기록'), findsOneWidget);
    // 진행 중인 과제가 마감된 과제보다 위에 온다.
    expect(
      tester.getTopLeft(find.text('XSS 필터 우회')).dy,
      lessThan(tester.getTopLeft(find.text('SQL Injection 실습 보고서')).dy),
    );
  });

  testWidgets('zip 파일을 골라 확인하면 multipart로 올린다', (tester) async {
    await pumpStudy(
      tester,
      pick: const PickedZip(name: '홍길동 XSS 과제.zip', bytes: zipBytes),
    );

    await tester.tap(
      find.descendant(
          of: cardOf('XSS 필터 우회'), matching: find.text('zip 파일 제출')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('홍길동 XSS 과제.zip (7B)'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '제출'));
    await tester.pumpAndSettle();

    final request =
        backend.sent('POST', '/api/assignments/32/submissions/').single;
    expect(request.headers['X-CSRFToken'], 'test-token');
    expect(request.headers['content-type'], startsWith('multipart/form-data'));
    final body = utf8.decode(request.bodyBytes, allowMalformed: true);
    expect(body, contains('name="file"; filename="홍길동 XSS 과제.zip"'));
    expect(find.text('과제를 제출했습니다.'), findsOneWidget);
    // 제출 후 최신 상태를 다시 불러온다.
    expect(backend.sent('GET', '/api/me/studies/1/'), hasLength(2));
  });

  testWidgets('취소하면 아무것도 올리지 않는다', (tester) async {
    await pumpStudy(tester);
    await tester.tap(find.text('zip 파일 제출'));
    await tester.pumpAndSettle();
    expect(find.text('과제 제출'), findsNothing);
    expect(backend.sent('POST', '/api/assignments/32/submissions/'), isEmpty);
  });

  for (final (name, bytes, message) in [
    ('report.pdf', zipBytes, 'zip 파일만 제출할 수 있습니다.'),
    ('fake.zip', [0x31, 0x32, 0x33], '올바른 zip 파일이 아닙니다.'),
    ('empty.zip', <int>[], '빈 파일은 제출할 수 없습니다.'),
  ]) {
    testWidgets('올리기 전에 거른다: $message', (tester) async {
      await pumpStudy(tester, pick: PickedZip(name: name, bytes: bytes));
      await tester.tap(find.text('zip 파일 제출'));
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
      expect(backend.sent('POST', '/api/assignments/32/submissions/'), isEmpty);
    });
  }

  testWidgets('기한이 지난 과제를 다시 내면 지각·교체 안내를 먼저 보여준다', (tester) async {
    await pumpStudy(
      tester,
      pick: const PickedZip(name: '수정본.zip', bytes: zipBytes),
    );
    await tester.tap(
      find.descendant(
        of: cardOf('SQL Injection 실습 보고서'),
        matching: find.text('다시 제출'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('지각 제출로 표시됩니다'), findsOneWidget);
    expect(find.textContaining('확인 상태가 초기화됩니다'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '제출'));
    await tester.pumpAndSettle();
    expect(find.text('제출했습니다. 기한이 지나 지각 제출로 표시됩니다.'), findsOneWidget);
  });

  testWidgets('서버가 거절하면 서버가 준 이유를 보여준다', (tester) async {
    backend.on(
      'POST',
      '/api/assignments/32/submissions/',
      (_) => <String, dynamic>{
        'code': 'invalid',
        'message': '파일 크기는 50MB 이하여야 합니다.',
        'fields': {
          'file': ['파일 크기는 50MB 이하여야 합니다.'],
        },
      },
      status: 400,
    );
    await pumpStudy(
      tester,
      pick: const PickedZip(name: 'big.zip', bytes: zipBytes),
    );
    await tester.tap(find.text('zip 파일 제출'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '제출'));
    await tester.pumpAndSettle();
    expect(find.text('파일 크기는 50MB 이하여야 합니다.'), findsOneWidget);
    expect(find.text('zip 파일 제출'), findsOneWidget);
  });

  testWidgets('수강 중이 아니면 제출 버튼 없이 안내만 보여준다', (tester) async {
    backend.on(
      'GET',
      '/api/me/studies/1/',
      (_) => myStudyDetailJson(canSubmit: false),
    );
    await pumpStudy(tester);
    expect(find.text('zip 파일 제출'), findsNothing);
    expect(find.text('다시 제출'), findsNothing);
    expect(find.textContaining('수료 상태에서는 과제를 제출할 수 없습니다.'), findsOneWidget);
  });

  testWidgets('마이페이지에서 제출할 과제를 보고 스터디 상세로 들어간다', (tester) async {
    setScreen(tester, const Size(1280, 1000));
    await tester.pumpWidget(const KuicsApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('마이페이지 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('마이페이지 (홍길동)'));
    await tester.pumpAndSettle();

    expect(find.text('제출할 과제 1개'), findsOneWidget);
    expect(find.text('스터디 관리'), findsNothing);

    await tester.tap(find.text('[예시] 웹해킹 입문 · 2099-1'));
    await tester.pumpAndSettle();
    expect(find.text('XSS 필터 우회'), findsOneWidget);

    // pageBack()은 영어 'Back' 툴팁을 찾으므로 한국어 로케일에서는 버튼을 직접 누른다.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    // 돌아오면 남은 과제 수를 다시 불러온다.
    expect(backend.sent('GET', '/api/me/studies/'), hasLength(2));
  });

  testWidgets('휴대폰 폭(360)에서 마이페이지와 스터디 상세가 넘치지 않는다', (tester) async {
    await pumpStudy(tester, size: const Size(360, 2200));

    setScreen(tester, const Size(360, 1600));
    await tester.pumpWidget(const KuicsApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Page'));
    await tester.pumpAndSettle();
    expect(find.text('제출할 과제 1개'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
