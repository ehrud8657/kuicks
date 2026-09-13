import 'fake_backend.dart';

Map<String, dynamic> memberJson({
  String role = 'leader',
  String name = '김스터디장',
  String studentId = '2099000001',
}) =>
    <String, dynamic>{
      'student_id': studentId,
      'name': name,
      'role': role,
      'must_change_password': false,
    };

List<Map<String, dynamic>> managedStudiesJson() => [
      <String, dynamic>{
        'id': 1,
        'title': '[예시] 웹해킹 입문',
        'semester': '2099-1',
        'leader_name': '김스터디장',
        'participant_count': 3,
        'session_count': 2,
        'assignment_count': 2,
        'unchecked_count': 1,
      },
    ];

Map<String, dynamic> _participant(
  int id,
  String name,
  String studentId,
  String status,
  Map<String, int> attendance,
  int submitted,
) =>
    <String, dynamic>{
      'id': id,
      'member_name': name,
      'student_id': studentId,
      'status': status,
      'status_label': status,
      'attendance': <String, dynamic>{
        'present': 0,
        'late': 0,
        'absent': 0,
        'excused': 0,
        ...attendance,
      },
      'submitted_count': submitted,
    };

List<Map<String, dynamic>> sessionsJson() => [
      <String, dynamic>{
        'id': 21,
        'number': 1,
        'title': 'OT',
        'held_on': '2099-03-02',
        'recorded_count': 4,
      },
      <String, dynamic>{
        'id': 22,
        'number': 2,
        'title': 'SQL Injection',
        'held_on': '2099-03-09',
        'recorded_count': 0,
      },
    ];

Map<String, dynamic> pastAssignmentJson() => <String, dynamic>{
      'id': 31,
      'title': 'SQL Injection 실습 보고서',
      'description':
          'DVWA Low/Medium 풀이 과정을 정리해 zip으로 제출하세요.\n참고: https://owasp.org',
      'due_at': '2020-03-10T23:59:00+09:00',
      'submitted_count': 2,
      'late_count': 1,
      'unchecked_count': 1,
      'missing_count': 1,
    };

Map<String, dynamic> studyDetailJson() => <String, dynamic>{
      'id': 1,
      'title': '[예시] 웹해킹 입문',
      'semester': '2099-1',
      'leader_name': '김스터디장',
      'description': 'OWASP Top 10을 실습 위주로 다룹니다.',
      'participants': [
        _participant(11, '홍길동', '2099000101', 'active', {'present': 1}, 1),
        _participant(
          12,
          '이영희',
          '2099000102',
          'active',
          {'late': 1},
          1,
        ),
        _participant(13, '박철수', '2099000103', 'active', {'absent': 1}, 0),
        _participant(14, '정민지', '2099000104', 'withdrawn', {'excused': 1}, 0),
      ],
      'sessions': sessionsJson(),
      'assignments': [
        pastAssignmentJson(),
        <String, dynamic>{
          'id': 32,
          'title': 'XSS 필터 우회',
          'description': '',
          'due_at': '2099-03-20T23:59:00+09:00',
          'submitted_count': 0,
          'late_count': 0,
          'unchecked_count': 0,
          'missing_count': 3,
        },
      ],
    };

Map<String, dynamic> attendanceMatrixJson() => <String, dynamic>{
      'sessions': sessionsJson(),
      'rows': [
        for (final (id, name, status, first) in [
          (11, '홍길동', 'active', 'present'),
          (12, '이영희', 'active', 'late'),
          (13, '박철수', 'active', 'absent'),
          (14, '정민지', 'withdrawn', 'excused'),
        ])
          <String, dynamic>{
            'participation_id': id,
            'member_name': name,
            'student_id': '20990001$id',
            'participation_status': status,
            'statuses': [first, null],
          },
      ],
    };

Map<String, dynamic> attendanceSheetJson() => <String, dynamic>{
      'session': sessionsJson()[1],
      'records': [
        for (final (id, name) in [(11, '홍길동'), (12, '이영희'), (13, '박철수')])
          <String, dynamic>{
            'participation_id': id,
            'member_name': name,
            'student_id': '20990001$id',
            'participation_status': 'active',
            'status': null,
            'note': '',
          },
      ],
    };

Map<String, dynamic> uncheckedSubmissionJson() => <String, dynamic>{
      'id': 42,
      'original_name': '이영희_보고서.zip',
      'size': 2 * 1024 * 1024,
      'submitted_at': '2020-03-11T01:00:00+09:00',
      'is_late': true,
      'review_status': 'pending',
      'feedback': '',
      'reviewed_at': null,
      'reviewed_by_name': null,
    };

Map<String, dynamic> submissionSheetJson() => <String, dynamic>{
      'assignment': pastAssignmentJson(),
      'rows': [
        <String, dynamic>{
          'participation_id': 11,
          'member_name': '홍길동',
          'student_id': '2099000101',
          'participation_status': 'active',
          'submission': <String, dynamic>{
            'id': 41,
            'original_name': '홍길동_SQLi.zip',
            'size': 20480,
            'submitted_at': '2020-03-09T20:00:00+09:00',
            'is_late': false,
            'review_status': 'checked',
            'feedback': '필터 우회 과정을 잘 정리했어요.',
            'reviewed_at': '2020-03-12T10:00:00+09:00',
            'reviewed_by_name': '김스터디장',
          },
        },
        <String, dynamic>{
          'participation_id': 12,
          'member_name': '이영희',
          'student_id': '2099000102',
          'participation_status': 'active',
          'submission': uncheckedSubmissionJson(),
        },
        <String, dynamic>{
          'participation_id': 13,
          'member_name': '박철수',
          'student_id': '2099000103',
          'participation_status': 'active',
          'submission': null,
        },
      ],
    };

/// 스터디장 김스터디장이 로그인한 상태의 가짜 서버 응답.
void registerManageRoutes(FakeBackend backend, {String role = 'leader'}) {
  backend
    ..on('GET', '/api/me/', (_) => memberJson(role: role))
    ..on(
      'GET',
      '/api/boards/',
      (_) => <String, dynamic>{
        'count': 0,
        'next': null,
        'previous': null,
        'results': <Object>[],
      },
    )
    ..on('GET', '/api/semesters/', (_) => <Object>[])
    ..on('GET', '/api/me/studies/', (_) => <Object>[])
    ..on('GET', '/api/manage/studies/', (_) => managedStudiesJson())
    ..on('GET', '/api/manage/studies/1/', (_) => studyDetailJson())
    ..on(
      'GET',
      '/api/manage/studies/1/attendance/',
      (_) => attendanceMatrixJson(),
    )
    ..on(
      'GET',
      '/api/manage/sessions/22/attendance/',
      (_) => attendanceSheetJson(),
    )
    ..on('PUT', '/api/manage/sessions/22/attendance/', (request) {
      final sent = {
        for (final record in decodeBody(request)['records'] as List)
          (record as Map<String, dynamic>)['participation_id']: record,
      };
      final sheet = attendanceSheetJson();
      for (final record in sheet['records'] as List) {
        final row = record as Map<String, dynamic>;
        final update = sent[row['participation_id']];
        if (update != null) {
          row['status'] = update['status'];
          row['note'] = update['note'];
        }
      }
      return sheet;
    })
    ..on(
      'GET',
      '/api/manage/assignments/31/submissions/',
      (_) => submissionSheetJson(),
    )
    ..on(
      'PATCH',
      '/api/manage/submissions/42/',
      (request) => <String, dynamic>{
        ...uncheckedSubmissionJson(),
        ...decodeBody(request),
        'reviewed_by_name': '김스터디장',
        'reviewed_at': '2020-03-12T10:00:00+09:00',
      },
    )
    ..on(
      'POST',
      '/api/manage/studies/1/assignments/',
      (request) {
        final body = decodeBody(request);
        return <String, dynamic>{
          'id': 99,
          'title': body['title'],
          'description': body['description'],
          'due_at': body['due_at'],
          'submitted_count': 0,
          'late_count': 0,
          'unchecked_count': 0,
          'missing_count': 3,
        };
      },
      status: 201,
    );
}
