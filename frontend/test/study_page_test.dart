import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuics_frontend/models.dart';
import 'package:kuics_frontend/pages/study_page.dart';
import 'package:kuics_frontend/widgets/common.dart';

import 'support/fake_backend.dart';

/// 스터디 카드의 진행 방식·일정·수료 요건 표시.
void main() {
  Map<String, dynamic> studyJson({
    String method = '',
    String schedule = '',
    String requirements = '',
  }) =>
      <String, dynamic>{
        'id': 1,
        'title': '웹해킹 입문',
        'leader_name': '김스터디장',
        'description': 'OWASP Top 10을 실습 위주로 다룹니다.',
        'prerequisites': '없음',
        'recommended': '웹 기초',
        'method': method,
        'schedule': schedule,
        'completion_requirements': requirements,
        'participations': <Object>[],
      };

  Finder info(String text) => find.byWidgetPredicate(
        (widget) => widget is KeepAllText && widget.data == text,
      );

  Future<void> pumpCard(WidgetTester tester, Map<String, dynamic> json,
      {Size size = const Size(1280, 900)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: SingleChildScrollView(
            child: StudyCard(study: Study.fromJson(json)),
          ),
        ),
      ),
    );
    await tester.tap(find.text('웹해킹 입문'));
    await tester.pumpAndSettle();
  }

  testWidgets('펼치면 진행 방식·일정·수료 요건을 보여준다', (tester) async {
    await pumpCard(
      tester,
      studyJson(
        method: '대면 · 매주 발표와 실습',
        schedule: '매주 화요일 19:00\n3월 ~ 6월',
        requirements: '출석 80% 이상, 과제 제출',
      ),
    );
    expect(find.text('진행 방식'), findsOneWidget);
    expect(info('대면 · 매주 발표와 실습'), findsOneWidget);
    expect(find.text('일정'), findsOneWidget);
    expect(info('매주 화요일 19:00\n3월 ~ 6월'), findsOneWidget);
    expect(find.text('수료 요건'), findsOneWidget);
    expect(info('출석 80% 이상, 과제 제출'), findsOneWidget);
    expect(find.text('선이수과목'), findsOneWidget);
  });

  testWidgets('적지 않은 항목은 숨기고, 예전 응답(필드 없음)도 그대로 열린다', (tester) async {
    final json = studyJson(schedule: '매주 목요일')
      ..remove('method')
      ..remove('completion_requirements');
    await pumpCard(tester, json);
    expect(find.text('진행 방식'), findsNothing);
    expect(find.text('수료 요건'), findsNothing);
    expect(info('매주 목요일'), findsOneWidget);
  });

  testWidgets('휴대폰 폭(360)에서 긴 안내도 넘치지 않는다', (tester) async {
    await pumpCard(
      tester,
      studyJson(
        method: '대면과 비대면을 번갈아 진행하며 매주 한 명씩 돌아가며 발표합니다.',
        schedule: '매주 화요일 19:00 ~ 21:00, 3월 둘째 주부터 6월 첫째 주까지 총 12회',
        requirements: '출석 80% 이상, 과제 제출 80% 이상, 최종 발표 참여',
      ),
      size: const Size(360, 800),
    );
    expect(tester.takeException(), isNull);
  });
}
