import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'format.dart';
// browser_client는 웹에서만 컴파일되므로 조건부 import로 분리한다.
// (직접 import하면 VM에서 도는 flutter test가 컴파일 단계에서 실패한다.)
import 'http_client_default.dart'
    if (dart.library.js_interop) 'http_client_web.dart';
import 'models.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.code, this.statusCode, this.fields});

  /// 사용자에게 그대로 보여줄 수 있는 문장.
  final String message;

  /// 서버 오류 식별자. 예: `password_change_required`, `permission_denied`.
  final String? code;
  final int? statusCode;

  /// 입력값 오류일 때 필드별 메시지.
  final Map<String, dynamic>? fields;

  bool get isPasswordChangeRequired => code == 'password_change_required';

  /// 필드별 첫 번째 오류 메시지.
  Map<String, String> get fieldMessages => {
        for (final entry in (fields ?? const <String, dynamic>{}).entries)
          if (entry.value is List && (entry.value as List).isNotEmpty)
            entry.key: '${(entry.value as List).first}',
      };

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? createHttpClient();
  final http.Client _client;

  /// 앱 전체가 함께 쓰는 인스턴스. 테스트에서는 MockClient를 넣은 인스턴스로 바꾼다.
  static ApiClient instance = ApiClient();

  /// 서버가 초기 비밀번호 변경을 요구할 때마다 값이 바뀐다.
  /// 앱 셸이 이 값을 듣고 강제 변경 창을 띄운다.
  static final passwordChangeRequired = ValueNotifier<int>(0);

  /// 로그인이 끊긴 상태로 로그인이 필요한 API를 부를 때마다 값이 바뀐다.
  static final loginRequired = ValueNotifier<int>(0);

  static const loginRequiredMessage = '로그인이 필요합니다. 다시 로그인해주세요.';

  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api',
  );

  /// 브라우저에서 새 창으로 열 주소. 상대 경로(`/api`)로 빌드된 경우 현재 사이트 기준으로 푼다.
  static Uri absoluteUrl(String path) => Uri.base.resolve('$baseUrl$path');

  /// 제출 파일 내려받기 주소. 세션 쿠키로 권한을 확인하므로 브라우저 이동으로 연다.
  static Uri submissionDownloadUrl(int submissionId) =>
      absoluteUrl('/submissions/$submissionId/download/');

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    return query == null || query.isEmpty
        ? uri
        : uri.replace(queryParameters: query);
  }

  static dynamic _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  /// 오류 응답을 ApiException으로 바꾼다. 서버는 {code, message, fields} 형식으로 응답한다.
  ApiException _error(http.Response response, String fallback) {
    var message = fallback;
    String? code;
    Map<String, dynamic>? fields;
    try {
      final body = _decode(response);
      if (body is Map<String, dynamic>) {
        final bodyMessage = body['message'] ?? body['detail'];
        if (bodyMessage is String && bodyMessage.isNotEmpty) {
          message = bodyMessage;
        }
        if (body['code'] is String) code = body['code'] as String;
        if (body['fields'] is Map<String, dynamic>) {
          fields = body['fields'] as Map<String, dynamic>;
        }
      }
    } catch (_) {
      // 응답이 JSON이 아니면(프록시 오류 페이지 등) 기본 메시지로 대체
    }
    if (response.statusCode == 413) {
      message = '파일이 너무 커서 서버가 받지 않았습니다.';
    }
    if (code == 'not_authenticated' || code == 'authentication_failed') {
      // 다른 탭에서 로그아웃했거나 세션이 끝난 경우. 앱이 로그인 창을 다시 띄운다.
      message = loginRequiredMessage;
      loginRequired.value++;
    }
    final error = ApiException(
      message,
      code: code,
      statusCode: response.statusCode,
      fields: fields,
    );
    if (error.isPasswordChangeRequired) passwordChangeRequired.value++;
    return error;
  }

  Future<dynamic> _get(
    String path, {
    Map<String, String>? query,
    required String fallback,
  }) async {
    final response = await _client.get(_uri(path, query));
    if (response.statusCode != 200) throw _error(response, fallback);
    return _decode(response);
  }

  // 로그인 시 서버가 CSRF 토큰을 rotate하므로 절대 캐싱하지 않고
  // 상태를 바꾸는 요청 직전마다 매번 새로 받아온다.
  Future<String> _fetchCsrfToken() async {
    final response = await _client.get(_uri('/auth/csrf/'));
    if (response.statusCode != 200) {
      throw ApiException('서버에 연결할 수 없습니다.');
    }
    final body = _decode(response) as Map<String, dynamic>;
    return body['csrfToken'] as String;
  }

  Future<dynamic> _finish(
      http.StreamedResponse streamed, String fallback) async {
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _error(response, fallback);
    }
    return _decode(response);
  }

  /// JSON 본문으로 상태를 바꾸는 요청(POST/PUT/PATCH/DELETE)을 보낸다.
  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    required String fallback,
  }) async {
    final token = await _fetchCsrfToken();
    final request = http.Request(method, _uri(path))
      ..headers['X-CSRFToken'] = token
      ..headers['Content-Type'] = 'application/json';
    if (body != null) request.body = jsonEncode(body);
    return _finish(await _client.send(request), fallback);
  }

  static List<dynamic> _items(dynamic body) =>
      body is List ? body : (body as Map<String, dynamic>)['results'] as List;

  static Map<String, dynamic> _map(dynamic body) =>
      body as Map<String, dynamic>;

  Future<List<Semester>> fetchSemesters() async {
    final body = await _get('/semesters/', fallback: '학기 정보를 불러오지 못했습니다.');
    return _items(body)
        .map((item) => Semester.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// 공지사항·모집공고 목록. [category]가 없으면 전체를 받는다.
  ///
  /// 서버가 20개 단위로 페이지네이션하므로 [page]로 이어서 받는다.
  /// (DRF가 주는 next는 절대 URL이라 프록시 뒤에서 어긋날 수 있어 쪽 번호를 쓴다.)
  Future<PostPage> fetchPosts({PostCategory? category, int page = 1}) async {
    final body = await _get(
      '/boards/',
      query: {
        if (category != null) 'category': category.name,
        if (page > 1) 'page': '$page',
      },
      fallback: '게시글을 불러오지 못했습니다.',
    );
    return PostPage(
      posts: _items(body)
          .map((item) => Post.fromJson(item as Map<String, dynamic>))
          .toList(),
      hasMore: body is Map<String, dynamic> && body['next'] != null,
    );
  }

  Future<List<MyStudy>> fetchMyStudies() async {
    final body = await _get(
      '/me/studies/',
      fallback: '스터디 참여 내역을 불러오지 못했습니다.',
    );
    return _items(body)
        .map((item) => MyStudy.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// 로그인 상태면 회원 정보, 아니면 null.
  Future<Member?> fetchMe() async {
    final response = await _client.get(_uri('/me/'));
    if (response.statusCode == 200) {
      return Member.fromJson(_decode(response) as Map<String, dynamic>);
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      return null;
    }
    throw ApiException('서버에 연결할 수 없습니다.');
  }

  Future<Member> login(String studentId, String password) async {
    final body = await _send(
      'POST',
      '/auth/login/',
      body: {'student_id': studentId, 'password': password},
      fallback: '학번 또는 비밀번호를 확인해주세요.',
    );
    return Member.fromJson(_map(body));
  }

  Future<void> logout() =>
      _send('POST', '/auth/logout/', fallback: '로그아웃에 실패했습니다.');

  Future<void> changePassword(String newPassword) => _send(
        'POST',
        '/auth/change-password/',
        body: {'new_password': newPassword},
        fallback: '비밀번호 변경에 실패했습니다.',
      );

  // ── 스터디 관리 (스터디장·운영진) ─────────────────────────────

  Future<List<ManagedStudy>> fetchManagedStudies() async {
    final body = await _get(
      '/manage/studies/',
      fallback: '관리할 스터디 목록을 불러오지 못했습니다.',
    );
    return _items(body)
        .map((item) => ManagedStudy.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ManagedStudyDetail> fetchManagedStudy(int studyId) async =>
      ManagedStudyDetail.fromJson(
        _map(
          await _get(
            '/manage/studies/$studyId/',
            fallback: '스터디 정보를 불러오지 못했습니다.',
          ),
        ),
      );

  Future<AttendanceMatrix> fetchAttendanceMatrix(int studyId) async =>
      AttendanceMatrix.fromJson(
        _map(
          await _get(
            '/manage/studies/$studyId/attendance/',
            fallback: '출석 현황을 불러오지 못했습니다.',
          ),
        ),
      );

  Future<void> updateParticipationStatus({
    required int studyId,
    required int participationId,
    required ParticipationStatus status,
  }) =>
      _send(
        'PATCH',
        '/studies/$studyId/participations/$participationId/',
        body: {'status': status.name},
        fallback: '참여 상태를 바꾸지 못했습니다.',
      );

  /// 회차를 추가하거나([sessionId]가 없을 때) 수정한다.
  Future<StudySessionInfo> saveSession({
    required int studyId,
    int? sessionId,
    required int number,
    required String title,
    required DateTime heldOn,
  }) async {
    final body = {
      'number': number,
      'title': title,
      'held_on': toApiDate(heldOn),
    };
    const fallback = '회차를 저장하지 못했습니다.';
    final result = sessionId == null
        ? await _send(
            'POST',
            '/manage/studies/$studyId/sessions/',
            body: body,
            fallback: fallback,
          )
        : await _send(
            'PATCH',
            '/manage/sessions/$sessionId/',
            body: body,
            fallback: fallback,
          );
    return StudySessionInfo.fromJson(_map(result));
  }

  Future<void> deleteSession(int sessionId) => _send(
        'DELETE',
        '/manage/sessions/$sessionId/',
        fallback: '회차를 삭제하지 못했습니다.',
      );

  Future<AttendanceSheet> fetchAttendance(int sessionId) async =>
      AttendanceSheet.fromJson(
        _map(
          await _get(
            '/manage/sessions/$sessionId/attendance/',
            fallback: '출석부를 불러오지 못했습니다.',
          ),
        ),
      );

  Future<AttendanceSheet> saveAttendance(
    int sessionId,
    List<AttendanceRecord> records,
  ) async =>
      AttendanceSheet.fromJson(
        _map(
          await _send(
            'PUT',
            '/manage/sessions/$sessionId/attendance/',
            body: {
              'records': records.map((record) => record.toJson()).toList()
            },
            fallback: '출석을 저장하지 못했습니다.',
          ),
        ),
      );

  /// 과제를 등록하거나([assignmentId]가 없을 때) 수정한다.
  Future<AssignmentInfo> saveAssignment({
    required int studyId,
    int? assignmentId,
    required String title,
    required String description,
    required DateTime dueAt,
  }) async {
    final body = {
      'title': title,
      'description': description,
      'due_at': dueAt.toUtc().toIso8601String(),
    };
    const fallback = '과제를 저장하지 못했습니다.';
    final result = assignmentId == null
        ? await _send(
            'POST',
            '/manage/studies/$studyId/assignments/',
            body: body,
            fallback: fallback,
          )
        : await _send(
            'PATCH',
            '/manage/assignments/$assignmentId/',
            body: body,
            fallback: fallback,
          );
    return AssignmentInfo.fromJson(_map(result));
  }

  Future<void> deleteAssignment(int assignmentId) => _send(
        'DELETE',
        '/manage/assignments/$assignmentId/',
        fallback: '과제를 삭제하지 못했습니다.',
      );

  Future<SubmissionSheet> fetchSubmissions(int assignmentId) async =>
      SubmissionSheet.fromJson(
        _map(
          await _get(
            '/manage/assignments/$assignmentId/submissions/',
            fallback: '제출 현황을 불러오지 못했습니다.',
          ),
        ),
      );

  Future<Submission> reviewSubmission(
    int submissionId, {
    ReviewStatus? reviewStatus,
    String? feedback,
  }) async =>
      Submission.fromJson(
        _map(
          await _send(
            'PATCH',
            '/manage/submissions/$submissionId/',
            body: {
              if (reviewStatus != null) 'review_status': reviewStatus.name,
              if (feedback != null) 'feedback': feedback,
            },
            fallback: '제출물 확인 상태를 저장하지 못했습니다.',
          ),
        ),
      );

  // ── 참여자: 스터디 상세·과제 제출 ─────────────────────────────

  Future<MyStudyDetail> fetchMyStudyDetail(int studyId) async =>
      MyStudyDetail.fromJson(
        _map(
          await _get(
            '/me/studies/$studyId/',
            fallback: '스터디 정보를 불러오지 못했습니다.',
          ),
        ),
      );

  /// zip 파일로 과제를 제출한다. 이미 냈으면 서버가 파일을 교체한다.
  Future<Submission> submitAssignment(
    int assignmentId, {
    required List<int> bytes,
    required String filename,
  }) async {
    final token = await _fetchCsrfToken();
    final request = http.MultipartRequest(
      'POST',
      _uri('/assignments/$assignmentId/submissions/'),
    )
      ..headers['X-CSRFToken'] = token
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );
    return Submission.fromJson(
      _map(await _finish(await _client.send(request), '과제를 제출하지 못했습니다.')),
    );
  }
}
