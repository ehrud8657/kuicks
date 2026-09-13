import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuics_frontend/api_client.dart';
import 'package:kuics_frontend/pages/board_page.dart';

import 'support/fake_backend.dart';

void main() {
  late FakeBackend backend;

  setUp(() {
    backend = FakeBackend()..install();
    backend.on(
      'GET',
      '/api/boards/',
      (_) => <String, dynamic>{
        'count': 0,
        'next': null,
        'previous': null,
        'results': <Object>[],
      },
    );
  });

  tearDown(() => ApiClient.instance = ApiClient());

  testWidgets('게시판 제목이 선택한 분류를 따라간다', (tester) async {
    await tester.pumpWidget(testApp(const Scaffold(body: BoardPage())));
    await tester.pumpAndSettle();
    expect(find.text('공지사항 · 모집공고'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '모집공고'));
    await tester.pumpAndSettle();
    // 분류 칩과 페이지 제목
    expect(find.text('모집공고'), findsNWidgets(2));
    expect(find.text('진행 중인 모집공고가 없습니다.'), findsOneWidget);
    expect(backend.sent('GET', '/api/boards/').last.url.queryParameters, {
      'category': 'recruit',
    });
  });
}
