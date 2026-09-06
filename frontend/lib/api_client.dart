import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart' as browser;
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

  static http.Client _createClient() {
    // 세션 쿠키 기반 인증이라 cross-origin 요청에도 쿠키가 실려야 한다.
    // (기본 http.Client는 브라우저에서 withCredentials가 꺼져있어 쿠키를 안 보낸다.)
    return browser.BrowserClient()..withCredentials = true;
  }

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
