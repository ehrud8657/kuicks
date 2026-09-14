import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuics_frontend/api_client.dart';
import 'package:kuics_frontend/models.dart';
import 'package:kuics_frontend/widgets/auth_dialogs.dart';

import 'support/fake_backend.dart';
import 'support/fixtures.dart';

void main() {
  late FakeBackend backend;
  Member? result;

  setUp(() {
    backend = FakeBackend()..install();
    result = null;
  });

  tearDown(() => ApiClient.instance = ApiClient());

  Future<void> openDialog(
    WidgetTester tester, {
    String? notice,
    Size size = const Size(1280, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<Member>(
                  context: context,
                  builder: (_) => LoginDialog(notice: notice),
                );
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  testWidgets('세션 만료 안내를 보여주고, 비어 있으면 서버에 보내지 않는다', (tester) async {
    await openDialog(tester, notice: ApiClient.loginRequiredMessage);
    expect(find.text('학번으로 로그인'), findsOneWidget);
    expect(find.text(ApiClient.loginRequiredMessage), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await tester.pumpAndSettle();
    expect(find.text('학번을 입력해주세요.'), findsOneWidget);
    expect(find.text('비밀번호를 입력해주세요.'), findsOneWidget);
    expect(backend.sent('POST', '/api/auth/login/'), isEmpty);
  });

  testWidgets('서버가 거절하면 안내 대신 이유를 보여준다', (tester) async {
    backend.on(
      'POST',
      '/api/auth/login/',
      (_) => <String, dynamic>{
        'code': 'invalid_credentials',
        'message': '학번 또는 비밀번호가 올바르지 않습니다.',
        'fields': null,
      },
      status: 400,
    );
    await openDialog(tester, notice: ApiClient.loginRequiredMessage);
    await tester.enterText(field('학번'), '2099000101');
    await tester.enterText(field('비밀번호'), 'wrong-password');
    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await tester.pumpAndSettle();

    expect(find.text('학번 또는 비밀번호가 올바르지 않습니다.'), findsOneWidget);
    expect(find.text(ApiClient.loginRequiredMessage), findsNothing);
    expect(find.byType(LoginDialog), findsOneWidget);
  });

  testWidgets('로그인에 성공하면 회원 정보를 돌려주며 닫힌다', (tester) async {
    backend.on(
      'POST',
      '/api/auth/login/',
      (_) => memberJson(role: 'member', name: '홍길동'),
    );
    await openDialog(tester);
    await tester.enterText(field('학번'), ' 2099000101 ');
    await tester.enterText(field('비밀번호'), 'Kuics-demo-2026!');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(LoginDialog), findsNothing);
    expect(result?.name, '홍길동');
    expect(backend.lastJson('POST', '/api/auth/login/')['student_id'],
        '2099000101');
  });

  testWidgets('닫기 버튼으로 닫고, 휴대폰 폭에서도 넘치지 않는다', (tester) async {
    await openDialog(
      tester,
      notice: ApiClient.loginRequiredMessage,
      size: const Size(360, 640),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginDialog), findsNothing);
    expect(result, isNull);
  });
}
