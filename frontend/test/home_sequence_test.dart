import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuics_frontend/api_client.dart';
import 'package:kuics_frontend/main.dart';
import 'package:kuics_frontend/widgets/meteor_shower.dart';
import 'package:kuics_frontend/widgets/tap_sequence.dart';

import 'support/fake_backend.dart';
import 'support/fixtures.dart';

void main() {
  final sequence = HomeTapSequence.instance;

  setUp(() {
    sequence
      ..reset()
      ..now = DateTime.now;
  });

  group('누르는 순서와 시간', () {
    late DateTime clock;
    late int fired;

    void onCompleted() => fired++;

    setUp(() {
      clock = DateTime(2026, 9, 15, 12);
      fired = 0;
      sequence.now = () => clock;
      sequence.completed.addListener(onCompleted);
      addTearDown(() => sequence.completed.removeListener(onCompleted));
    });

    void press(void Function() tap, int times, Duration gap) {
      for (var i = 0; i < times; i++) {
        tap();
        clock = clock.add(gap);
      }
    }

    const quick = Duration(milliseconds: 300);

    test('로고 2번 + 제목 6번을 5초 안에 누르면 한 번 알린다', () {
      press(sequence.logoTapped, 2, quick);
      press(sequence.titleTapped, 6, quick);
      expect(fired, 1);
    });

    test('첫 누름부터 5초가 지나면 알리지 않는다', () {
      const slow = Duration(milliseconds: 760);
      press(sequence.logoTapped, 2, slow);
      press(sequence.titleTapped, 6, slow);
      expect(fired, 0);
    });

    test('정확히 5초째의 마지막 누름까지는 인정한다', () {
      press(sequence.logoTapped, 2, const Duration(milliseconds: 714));
      press(sequence.titleTapped, 5, const Duration(milliseconds: 714));
      clock = DateTime(2026, 9, 15, 12, 0, 5);
      sequence.titleTapped();
      expect(fired, 1);
    });

    test('제목을 먼저 누르거나 로고를 1번만 누르면 알리지 않는다', () {
      press(sequence.titleTapped, 6, quick);
      press(sequence.logoTapped, 1, quick);
      press(sequence.titleTapped, 6, quick);
      expect(fired, 0);
    });

    test('제목을 누르다가 로고를 다시 누르면 처음부터 센다', () {
      press(sequence.logoTapped, 2, quick);
      press(sequence.titleTapped, 3, quick);
      press(sequence.logoTapped, 1, quick);
      press(sequence.titleTapped, 6, quick);
      expect(fired, 0);
    });

    test('로고를 3번 누르면 마지막 2번부터 센다', () {
      press(sequence.logoTapped, 3, quick);
      press(sequence.titleTapped, 6, quick);
      expect(fired, 1);
    });
  });

  group('홈 화면', () {
    late FakeBackend backend;

    setUp(() {
      backend = FakeBackend()..install();
      registerMemberRoutes(backend);
    });

    tearDown(() => ApiClient.instance = ApiClient());

    Future<void> open(WidgetTester tester, String location) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(KuicsApp(initialLocation: location));
      await tester.pumpAndSettle();
    }

    Finder logo() => find
        .ancestor(of: find.text('KUICS'), matching: find.byType(InkWell))
        .first;

    Future<void> tapTitle(WidgetTester tester, int times) async {
      for (var i = 0; i < times; i++) {
        await tester.tapOnText(find.textRange.ofSubstring('보안'));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('로고 2번 + "보안" 6번이면 연출이 떴다가 끝나면 사라진다', (tester) async {
      await open(tester, '/');
      expect(find.text('보안을 배우고,\n함께 성장합니다.'), findsOneWidget);

      for (var i = 0; i < 2; i++) {
        await tester.tap(logo());
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tapTitle(tester, 6);
      await tester.pump();
      expect(find.byType(MeteorShower), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
      await tester.pump(MeteorShower.duration);
      await tester.pumpAndSettle();
      expect(find.byType(MeteorShower), findsNothing);
    });

    testWidgets('연출 중 화면을 누르면 바로 끝난다', (tester) async {
      await open(tester, '/');
      for (var i = 0; i < 2; i++) {
        await tester.tap(logo());
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tapTitle(tester, 6);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tapAt(const Offset(640, 450));
      await tester.pump();
      expect(find.byType(MeteorShower), findsNothing);
    });

    testWidgets('다른 화면에서 누른 로고는 세지 않는다', (tester) async {
      await open(tester, '/study');
      // 첫 번째는 Study 화면에서 눌러 홈으로 이동만 한다.
      await tester.tap(logo());
      await tester.pumpAndSettle();
      await tester.tap(logo());
      await tester.pump(const Duration(milliseconds: 50));
      await tapTitle(tester, 6);
      await tester.pump();
      expect(find.byType(MeteorShower), findsNothing);
    });
  });
}
