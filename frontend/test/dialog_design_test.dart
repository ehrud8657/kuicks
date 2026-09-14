import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuics_frontend/api_client.dart';
import 'package:kuics_frontend/models.dart';
import 'package:kuics_frontend/pages/manage/forms.dart';
import 'package:kuics_frontend/widgets/app_dialog.dart';
import 'package:kuics_frontend/widgets/auth_dialogs.dart';
import 'package:kuics_frontend/widgets/common.dart';

import 'support/fake_backend.dart';
import 'support/fixtures.dart';

/// 공통 창 틀(AppDialog)로 바꾼 창들의 동작과 휴대폰 폭 표시를 확인한다.
void main() {
  setUp(() => FakeBackend()..install());
  tearDown(() => ApiClient.instance = ApiClient());

  void setScreen(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// 버튼을 눌러 [open]으로 창을 띄우고, 창이 돌려준 값을 [results]에 쌓는다.
  Future<List<Object?>> pumpOpener(
    WidgetTester tester,
    Future<Object?> Function(BuildContext context) open,
  ) async {
    final results = <Object?>[];
    await tester.pumpWidget(
      testApp(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => results.add(await open(context)),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('확인 창: 확인은 true, 취소·닫기는 false', (tester) async {
    setScreen(tester, const Size(1280, 900));
    final results = await pumpOpener(
      tester,
      (context) => confirmAction(
        context,
        title: '과제 삭제',
        message: '되돌릴 수 없습니다.',
        confirmLabel: '삭제',
        icon: Icons.delete_outline,
      ),
    );
    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '삭제'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();

    expect(results, [true, false, false]);
  });

  testWidgets('강제 비밀번호 변경 창은 닫기 버튼이 없고 로그아웃을 고를 수 있다', (tester) async {
    setScreen(tester, const Size(1280, 900));
    final results = await pumpOpener(
      tester,
      (context) => showDialog<PasswordDialogResult>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const ChangePasswordDialog(forced: true),
      ),
    );
    expect(find.byTooltip('닫기'), findsNothing);
    expect(find.textContaining('처음 로그인하셨네요'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '변경'));
    await tester.pumpAndSettle();
    expect(find.text('새 비밀번호를 입력해주세요.'), findsOneWidget);

    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    expect(results, [PasswordDialogResult.logout]);
  });

  testWidgets('선택 비밀번호 변경 창은 닫기로 닫힌다', (tester) async {
    setScreen(tester, const Size(1280, 900));
    final results = await pumpOpener(
      tester,
      (context) => showDialog<PasswordDialogResult>(
        context: context,
        builder: (_) => const ChangePasswordDialog(forced: false),
      ),
    );
    expect(find.textContaining('처음 로그인하셨네요'), findsNothing);
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    expect(results, [null]);
  });

  final dialogs = <String, Widget Function()>{
    '로그인': () => const LoginDialog(notice: '로그인이 필요합니다. 다시 로그인해주세요.'),
    '비밀번호 변경': () => const ChangePasswordDialog(forced: true),
    '회차 추가': () => const SessionFormDialog(studyId: 1, nextNumber: 4),
    '과제 등록': () => const AssignmentFormDialog(studyId: 1),
    '피드백': () => FeedbackDialog(
          submission: Submission.fromJson(uncheckedSubmissionJson()),
          memberName: '아주긴이름을가진참여자',
        ),
  };
  for (final MapEntry(key: name, value: build) in dialogs.entries) {
    testWidgets('휴대폰 폭(360)에서 $name 창이 넘치지 않는다', (tester) async {
      setScreen(tester, const Size(360, 640));
      await pumpOpener(
        tester,
        (context) => showDialog<Object?>(
          context: context,
          builder: (_) => build(),
        ),
      );
      expect(find.byType(AppDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('창 제목은 따로 읽히는 제목이자 창의 이름이다', (tester) async {
    setScreen(tester, const Size(1280, 900));
    final semantics = tester.ensureSemantics();
    await pumpOpener(
      tester,
      (context) => confirmAction(
        context,
        title: '회차 삭제',
        message: '되돌릴 수 없습니다.',
        confirmLabel: '삭제',
      ),
    );
    expect(
      tester.getSemantics(find.text('회차 삭제')),
      isSemantics(
        label: 'CONFIRM\n회차 삭제',
        isHeader: true,
        namesRoute: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('휴대폰 폭(360)에서 긴 확인 문구도 스크롤로 보인다', (tester) async {
    setScreen(tester, const Size(360, 480));
    await pumpOpener(
      tester,
      (context) => confirmAction(
        context,
        title: '다시 제출',
        message: List.filled(12, '이전에 낸 파일은 이 파일로 바뀝니다.').join('\n'),
        confirmLabel: '제출',
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(FilledButton, '제출'), findsOneWidget);
  });
}
