import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuics_frontend/models.dart';
import 'package:kuics_frontend/pages/activity_detail_page.dart';
import 'package:kuics_frontend/pages/activity_page.dart';
import 'package:kuics_frontend/widgets/upload_picker.dart';

import 'support/fake_backend.dart';

Map<String, dynamic> activityJson({
  int id = 12,
  String kind = 'project',
  String semester = '2026-2',
  String title = 'Team B',
  String topic = '웹 퍼징 도구',
  List<String> stages = const ['interim'],
}) =>
    {
      'id': id,
      'kind': kind,
      'semester': semester,
      'title': title,
      'topic': topic,
      'summary': '',
      'status': 'ongoing',
      'start_date': null,
      'end_date': null,
      'result': kind == 'contest' ? '32위' : '',
      'tags': ['web'],
      'members': [
        {'name': '김팀장', 'role': 'leader'},
        {'name': '이팀원', 'role': 'member'},
      ],
      'material_count': stages.length,
      'stages': stages,
    };

Map<String, dynamic> materialJson({
  bool canEdit = false,
  String stage = 'interim',
  bool isPublic = true,
}) =>
    {
      'id': 31,
      'stage': stage,
      'is_public': isPublic,
      'title': '중간 발표',
      'description': 'https://github.com/kuics/fuzz',
      'date': '2026-11-10',
      'author_name': '김팀장',
      'created_at': '2026-11-10T10:00:00Z',
      'updated_at': '2026-11-10T10:00:00Z',
      'files': [
        {
          'id': 41,
          'name': '중간발표.pdf',
          'size': 2048,
          'content_type': 'application/pdf',
          'is_image': false,
          'url': 'http://localhost/api/activities/files/41/',
        },
      ],
      'can_edit': canEdit,
    };

Map<String, dynamic> detailJson({
  bool canContribute = false,
  List<Object>? materials,
}) =>
    {
      ...activityJson(),
      'description': '',
      'team_name': '',
      'location': '',
      'materials': materials ?? [materialJson()],
      'can_contribute': canContribute,
    };

Map<String, dynamic> pageOf(List<Object> results) => {
      'count': results.length,
      'next': null,
      'previous': null,
      'results': results,
    };

void main() {
  late FakeBackend backend;

  void setScreen(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  setUp(() {
    backend = FakeBackend()..install();
    backend
      ..on(
        'GET',
        '/api/activities/filters/',
        (_) => {
          'semesters': ['2026-2', '2026-1'],
          'tags': ['web'],
        },
      )
      ..on(
        'GET',
        '/api/activities/',
        (_) => pageOf([
          activityJson(),
          activityJson(
            id: 5,
            kind: 'contest',
            semester: '2026-1',
            title: 'DEFCON Quals',
          ),
        ]),
      );
  });

  testWidgets('목록은 학기별로 묶고 프로젝트 진행 단계를 보여준다', (tester) async {
    await tester.pumpWidget(testApp(const Scaffold(body: ActivityPage())));
    await tester.pumpAndSettle();

    expect(find.text('Team B'), findsOneWidget);
    expect(find.text('웹 퍼징 도구'), findsOneWidget);
    expect(find.text('DEFCON Quals'), findsOneWidget);
    expect(find.text('32위'), findsOneWidget);
    // 학기 제목(목록)과 학기 선택 칩에 각각 나온다.
    expect(find.text('2026-1'), findsNWidgets(2));
    expect(find.text('팀장 김팀장 · 2명'), findsNWidgets(2));
    // 프로젝트 카드는 중간·최종 보고서 표시, 대회 카드는 자료 개수.
    expect(find.text('최종 보고서'), findsOneWidget);
    expect(find.text('자료 1개'), findsOneWidget);
  });

  testWidgets('종류와 태그를 고르면 그 조건으로 다시 불러온다', (tester) async {
    await tester.pumpWidget(testApp(const Scaffold(body: ActivityPage())));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, '대회'));
    await tester.pumpAndSettle();
    expect(backend.sent('GET', '/api/activities/').last.url.queryParameters,
        {'kind': 'contest'});

    await tester.tap(find.widgetWithText(FilterChip, '#web'));
    await tester.pumpAndSettle();
    expect(backend.sent('GET', '/api/activities/').last.url.queryParameters,
        {'kind': 'contest', 'tag': 'web'});
  });

  testWidgets('상세는 자료와 첨부를 보여주고, 권한이 없으면 올리기 버튼이 없다', (tester) async {
    backend.on('GET', '/api/activities/12/', (_) => detailJson());
    await tester.pumpWidget(testApp(const Scaffold(
      body: ActivityDetailPage(kind: ActivityKind.project, activityId: 12),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Team B'), findsOneWidget);
    expect(find.text('김팀장 · 팀장'), findsOneWidget);
    expect(find.text('자료 1개'), findsOneWidget);
    expect(find.text('중간 발표'), findsOneWidget);
    expect(find.text('중간발표.pdf'), findsOneWidget);
    expect(find.text('자료 올리기'), findsNothing);
    expect(find.byTooltip('자료 메뉴'), findsNothing);
    expect(find.text('비공개'), findsNothing);
  });

  testWidgets('비공개 자료에는 비공개 표시가 붙는다', (tester) async {
    backend.on(
      'GET',
      '/api/activities/12/',
      (_) => detailJson(materials: [
        materialJson(stage: 'activity', isPublic: false),
      ]),
    );
    await tester.pumpWidget(testApp(const Scaffold(
      body: ActivityDetailPage(kind: ActivityKind.project, activityId: 12),
    )));
    await tester.pumpAndSettle();
    expect(find.text('활동 보고서'), findsOneWidget);
    expect(find.text('비공개'), findsOneWidget);
  });

  testWidgets('공개 체크는 활동 보고서는 꺼짐, 중간·최종은 켜짐으로 고정, 기타만 고른다', (tester) async {
    backend
      ..on('GET', '/api/activities/12/',
          (_) => detailJson(canContribute: true, materials: []))
      ..on(
          'POST',
          '/api/activities/12/materials/',
          (_) => materialJson(stage: 'other', isPublic: false)
            ..['files'] = <Object>[],
          status: 201);
    await tester.pumpWidget(testApp(const Scaffold(
      body: ActivityDetailPage(kind: ActivityKind.project, activityId: 12),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('자료 올리기'));
    await tester.pumpAndSettle();

    CheckboxListTile publicBox() =>
        tester.widget(find.widgetWithText(CheckboxListTile, '공개'));
    Future<void> pickStage(String label) async {
      await tester.tap(find.descendant(
        of: find.byType(SegmentedButton<MaterialStage>),
        matching: find.text(label),
      ));
      await tester.pumpAndSettle();
    }

    // 새 자료는 활동 보고서로 시작한다.
    expect(publicBox().value, isFalse);
    expect(publicBox().onChanged, isNull);

    for (final label in ['중간 보고서', '최종 보고서']) {
      await pickStage(label);
      expect(publicBox().value, isTrue, reason: label);
      expect(publicBox().onChanged, isNull, reason: label);
    }

    await pickStage('기타');
    expect(publicBox().value, isTrue);
    expect(publicBox().onChanged, isNotNull);
    await tester.tap(find.widgetWithText(CheckboxListTile, '공개'));
    await tester.pumpAndSettle();
    expect(publicBox().value, isFalse);

    await tester.enterText(find.widgetWithText(TextFormField, '제목'), '회의록');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(backend.lastJson('POST', '/api/activities/12/materials/'), {
      'stage': 'other',
      'is_public': false,
      'title': '회의록',
      'description': '',
    });
  });

  testWidgets('없거나 비공개인 활동은 안내 문구를 보여준다', (tester) async {
    await tester.pumpWidget(testApp(const Scaffold(
      body: ActivityDetailPage(kind: ActivityKind.project, activityId: 99),
    )));
    await tester.pumpAndSettle();
    expect(find.text('없는 활동이거나 아직 공개되지 않았습니다.'), findsOneWidget);
  });

  testWidgets('참여자는 자료를 저장한 뒤 파일을 한 개씩 올린다', (tester) async {
    var saved = false;
    backend
      ..on(
        'GET',
        '/api/activities/12/',
        (_) => detailJson(
          canContribute: true,
          materials: saved ? [materialJson(canEdit: true)] : [],
        ),
      )
      ..on('POST', '/api/activities/12/materials/', (_) {
        saved = true;
        return materialJson(canEdit: true)..['files'] = <Object>[];
      }, status: 201)
      ..on(
        'POST',
        '/api/activities/materials/31/files/',
        (_) => (materialJson()['files'] as List).first,
        status: 201,
      );

    await tester.pumpWidget(testApp(Scaffold(
      body: ActivityDetailPage(
        kind: ActivityKind.project,
        activityId: 12,
        pickFiles: () async =>
            [PickedUpload(name: '최종보고서.pdf', bytes: List.filled(10, 1))],
      ),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('자료 올리기'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(SegmentedButton<MaterialStage>),
      matching: find.text('최종 보고서'),
    ));
    await tester.enterText(find.widgetWithText(TextFormField, '제목'), '최종 보고서');
    await tester.tap(find.text('파일 첨부'));
    await tester.pumpAndSettle();
    expect(find.text('최종보고서.pdf'), findsOneWidget);

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(backend.lastJson('POST', '/api/activities/12/materials/'), {
      'stage': 'final',
      'is_public': true,
      'title': '최종 보고서',
      'description': '',
    });
    expect(backend.sent('POST', '/api/activities/materials/31/files/'),
        hasLength(1));
    expect(find.text('자료를 올렸습니다.'), findsOneWidget);
    expect(find.byTooltip('자료 메뉴'), findsOneWidget);
  });

  testWidgets('휴대폰 폭(360)에서도 자료 올리기 창이 넘치지 않는다', (tester) async {
    setScreen(tester, const Size(360, 740));
    backend.on('GET', '/api/activities/12/',
        (_) => detailJson(canContribute: true, materials: []));
    await tester.pumpWidget(testApp(const Scaffold(
      body: ActivityDetailPage(kind: ActivityKind.project, activityId: 12),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('자료 올리기'));
    await tester.pumpAndSettle();
    expect(find.text('활동 보고서'), findsOneWidget);
  });
}
