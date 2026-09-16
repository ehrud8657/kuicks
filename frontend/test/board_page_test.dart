import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuics_frontend/api_client.dart';
import 'package:kuics_frontend/pages/board_page.dart';

import 'support/fake_backend.dart';

Map<String, dynamic> post({List<Object> attachments = const []}) => {
      'id': 1,
      'category': 'notice',
      'title': '스터디 신청 안내',
      'content': '신청은 이번 주까지입니다.',
      'author_name': '운영진',
      'is_pinned': false,
      'published_at': '2026-09-16T10:00:00Z',
      'attachments': attachments,
    };

Map<String, dynamic> attachment({
  int id = 1,
  String name = '포스터.png',
  int size = 1024,
  String contentType = 'image/png',
  bool isImage = true,
}) =>
    {
      'id': id,
      'name': name,
      'size': size,
      'content_type': contentType,
      'is_image': isImage,
      'url': 'http://localhost/api/boards/attachments/$id/',
    };

void serve(FakeBackend backend, List<Object> posts) => backend.on(
      'GET',
      '/api/boards/',
      (_) => <String, dynamic>{
        'count': posts.length,
        'next': null,
        'previous': null,
        'results': posts,
      },
    );

Future<void> openFirstPost(WidgetTester tester) async {
  await tester.pumpWidget(testApp(const Scaffold(body: BoardPage())));
  await tester.pumpAndSettle();
  await tester.tap(find.text('스터디 신청 안내'));
  await tester.pumpAndSettle();
}

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

  testWidgets('첨부가 없는 글에는 첨부 영역이 나오지 않는다', (tester) async {
    serve(backend, [post()]);
    await openFirstPost(tester);

    expect(find.text('신청은 이번 주까지입니다.'), findsOneWidget);
    expect(find.byType(PostImages), findsNothing);
    expect(find.byType(PostFiles), findsNothing);
  });

  testWidgets('사진과 문서가 각각 알맞은 모양으로 나온다', (tester) async {
    serve(backend, [
      post(attachments: [
        attachment(),
        attachment(
          id: 2,
          name: '회칙.pdf',
          size: 2 * 1024 * 1024,
          contentType: 'application/pdf',
          isImage: false,
        ),
      ]),
    ]);
    await openFirstPost(tester);

    // 사진은 본문 아래에 바로, 문서는 내려받기 줄로.
    expect(find.byType(PostImages), findsOneWidget);
    expect(find.byType(PostFiles), findsOneWidget);
    expect(find.text('회칙.pdf'), findsOneWidget);
    expect(find.text('2MB'), findsOneWidget);
    // 문서 줄에만 내려받기 표시가 붙는다.
    expect(
      find.descendant(
        of: find.byType(PostFiles),
        matching: find.byIcon(Icons.download_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets('사진을 불러오지 못하면 내려받기 줄로 대신 보여준다', (tester) async {
    // 테스트 환경에서는 실제 이미지 요청이 막히므로 이 경로가 그대로 실행된다.
    // 회원이 느린 망에 있을 때도 최소한 파일은 받을 수 있어야 한다.
    serve(backend, [
      post(attachments: [attachment(name: '모집포스터.png', size: 3 * 1024)]),
    ]);
    await openFirstPost(tester);

    expect(find.byType(PostImages), findsOneWidget);
    expect(find.text('모집포스터.png'), findsOneWidget);
    expect(find.text('3KB'), findsOneWidget);
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });
}
