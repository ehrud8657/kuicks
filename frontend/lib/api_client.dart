import 'dart:convert';
import 'package:http/http.dart' as http;
// browser_client는 웹에서만 컴파일되므로 조건부 import로 분리한다.
// (직접 import하면 VM에서 도는 flutter test가 컴파일 단계에서 실패한다.)
import 'http_client_default.dart'
    if (dart.library.js_interop) 'http_client_web.dart';
import 'models.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? _createClient();
  final http.Client _client;

  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api',
  );

  static http.Client _createClient() => createHttpClient();

  // 로그인 시 서버가 CSRF 토큰을 rotate하므로 절대 캐싱하지 않고
  // 상태를 바꾸는 요청(POST) 직전마다 매번 새로 받아온다.
  Future<String> _fetchCsrfToken() async {
    final response = await _client.get(Uri.parse('$baseUrl/auth/csrf/'));
    if (response.statusCode != 200) {
      throw ApiException('서버에 연결할 수 없습니다.');
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return body['csrfToken'] as String;
  }

  Future<http.Response> _unsafePost(String path, Map<String, dynamic> body) async {
    final token = await _fetchCsrfToken();
    return _client.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json', 'X-CSRFToken': token},
      body: jsonEncode(body),
    );
  }

  String _errorMessage(http.Response response, String fallback) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic>) {
        // DRF의 ValidationError/PermissionDenied는 message가 아니라 detail로 내려온다
        // (예: CSRF 실패, 인증 만료 등). message를 우선하되 detail도 놓치지 않는다.
        if (body['message'] is String) return body['message'] as String;
        if (body['detail'] is String) return body['detail'] as String;
      }
    } catch (_) {
      // 응답이 JSON이 아니면 기본 메시지로 대체
    }
    return fallback;
  }

  Future<List<Semester>> fetchSemesters() async {
    final response = await _client.get(Uri.parse('$baseUrl/semesters/'));
    if (response.statusCode != 200) {
      throw ApiException('학기 정보를 불러오지 못했습니다.');
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    final items = body is List ? body : body['results'] as List<dynamic>;
    return items
        .map((item) => Semester.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// 공지사항·모집공고 목록. [category]가 없으면 전체를 받는다.
  ///
  /// 서버가 20개 단위로 페이지네이션하므로 [page]로 이어서 받는다.
  /// (DRF가 주는 next는 절대 URL이라 프록시 뒤에서 어긋날 수 있어 쪽 번호를 쓴다.)
  Future<PostPage> fetchPosts({PostCategory? category, int page = 1}) async {
    final query = <String, String>{
      if (category != null) 'category': category.name,
      if (page > 1) 'page': '$page',
    };
    final uri = Uri.parse('$baseUrl/boards/').replace(
      queryParameters: query.isEmpty ? null : query,
    );
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw ApiException('게시글을 불러오지 못했습니다.');
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    final items = body is List ? body : body['results'] as List<dynamic>;
    return PostPage(
      posts: items
          .map((item) => Post.fromJson(item as Map<String, dynamic>))
          .toList(),
      hasMore: body is Map<String, dynamic> && body['next'] != null,
    );
  }

  Future<List<MyStudy>> fetchMyStudies() async {
    final response = await _client.get(Uri.parse('$baseUrl/me/studies/'));
    if (response.statusCode != 200) {
      throw ApiException('스터디 참여 내역을 불러오지 못했습니다.');
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    final items = body is List ? body : body['results'] as List<dynamic>;
    return items
        .map((item) => MyStudy.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Member?> fetchMe() async {
    final response = await _client.get(Uri.parse('$baseUrl/me/'));
    if (response.statusCode == 200) {
      return Member.fromJson(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      return null;
    }
    throw ApiException('서버에 연결할 수 없습니다.');
  }

  Future<Member> login(String studentId, String password) async {
    final response = await _unsafePost('/auth/login/', {
      'student_id': studentId,
      'password': password,
    });
    if (response.statusCode == 200) {
      return Member.fromJson(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
    }
    throw ApiException(_errorMessage(response, '학번 또는 비밀번호를 확인해주세요.'));
  }

  Future<void> logout() async {
    final response = await _unsafePost('/auth/logout/', const {});
    if (response.statusCode != 204) {
      throw ApiException('로그아웃에 실패했습니다.');
    }
  }

  Future<void> changePassword(String newPassword) async {
    final response = await _unsafePost('/auth/change-password/', {
      'new_password': newPassword,
    });
    if (response.statusCode != 200) {
      throw ApiException(_errorMessage(response, '비밀번호 변경에 실패했습니다.'));
    }
  }
}
