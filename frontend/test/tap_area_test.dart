import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kuics_frontend/api_client.dart';
import 'package:kuics_frontend/main.dart';
import 'package:kuics_frontend/widgets/common.dart';

import 'support/fake_backend.dart';
import 'support/fixtures.dart';

/// 카드처럼 보이는 곳은 어디를 눌러도 반응해야 한다 (오른쪽 빈 곳 포함).
void main() {
  tearDown(() => ApiClient.instance = ApiClient());

  void setScreen(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  for (final accent in [true, false]) {
    testWidgets('SoftCard(accent: $accent) 안의 InkWell은 카드 폭 전체가 눌린다',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 320,
                child: SoftCard(
                  accent: accent,
                  child: InkWell(
                    onTap: () => taps++,
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Text('짧은 제목')],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final card = tester.getRect(find.byType(Card));
      expect(card.width, 320);
      // 구분 막대(3px)가 있으면 그만큼 안쪽에서 시작하고, 나머지 폭은 모두 눌려야 한다.
      expect(
        tester.getRect(find.byType(InkWell)).width,
        card.width - (accent ? 3 : 0),
      );

      await tester.tapAt(Offset(card.right - 6, card.center.dy));
      expect(taps, 1);
    });
  }

  testWidgets('스터디 관리 목록 카드는 오른쪽 끝을 눌러도 열린다', (tester) async {
    final backend = FakeBackend()..install();
    registerManageRoutes(backend);
    setScreen(tester, const Size(1280, 900));
    await tester.pumpWidget(const KuicsApp(initialLocation: '/manage'));
    await tester.pumpAndSettle();

    final card = tester.getRect(
      find
          .ancestor(
            of: find.text('[예시] 웹해킹 입문'),
            matching: find.byType(Card),
          )
          .first,
    );
    await tester.tapAt(Offset(card.right - 6, card.center.dy));
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.byType(Navigator).first));
    expect(router.state.uri.path, '/manage/studies/1/participants');
  });
}
