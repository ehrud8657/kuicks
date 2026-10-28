import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuics_frontend/widgets/my_studies_panel.dart';

import 'support/fake_backend.dart';
import 'support/fixtures.dart';

void main() {
  late FakeBackend backend;

  setUp(() => backend = FakeBackend()..install());

  Future<void> pumpPanel(WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(const Scaffold(body: MyStudiesPanel())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('수강 중인 스터디만 보여주고 남은 과제 수를 붙인다', (tester) async {
    backend.on('GET', '/api/me/studies/', (_) => myStudiesJson());
    await pumpPanel(tester);

    expect(find.text('수강 중인 스터디 · 제출할 과제 1개'), findsOneWidget);
    expect(find.text('[예시] 웹해킹 입문 · 2099-1'), findsOneWidget);
    expect(find.text('과제 1'), findsOneWidget);
    // 완료한 스터디는 마이페이지에서만 본다.
    expect(find.textContaining('[예시] 리버싱 기초'), findsNothing);
  });

  testWidgets('수강 중인 스터디가 없거나 불러오지 못하면 아무것도 그리지 않는다', (tester) async {
    backend.on(
      'GET',
      '/api/me/studies/',
      (_) => [
        for (final study in myStudiesJson())
          if (study['status'] != 'active') study,
      ],
    );
    await pumpPanel(tester);
    expect(find.textContaining('수강 중인 스터디'), findsNothing);

    backend.on('GET', '/api/me/studies/', (_) => <Object>[], status: 500);
    await tester.pumpWidget(const SizedBox());
    await pumpPanel(tester);
    expect(find.textContaining('수강 중인 스터디'), findsNothing);
  });
}
