import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kuics_frontend/api_client.dart';

http.Response jsonResponse(Object body, int status) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  test('서버 오류 형식의 code와 message를 ApiException에 담는다', () async {
    final client = ApiClient(
      client: MockClient(
        (request) async => jsonResponse(
          {'code': 'permission_denied', 'message': '권한이 없습니다.', 'fields': null},
          403,
        ),
      ),
    );
    await expectLater(
      client.fetchMyStudies(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'permission_denied')
            .having((e) => e.message, 'message', '권한이 없습니다.')
            .having((e) => e.statusCode, 'statusCode', 403),
      ),
    );
  });

  test('password_change_required를 받으면 앱 셸에 알린다', () async {
    final client = ApiClient(
      client: MockClient(
        (request) async => jsonResponse(
          {
            'code': 'password_change_required',
            'message': '초기 비밀번호를 변경한 뒤 이용할 수 있습니다.',
            'fields': null,
          },
          403,
        ),
      ),
    );
    final before = ApiClient.passwordChangeRequired.value;
    await expectLater(client.fetchMyStudies(), throwsA(isA<ApiException>()));
    expect(ApiClient.passwordChangeRequired.value, before + 1);
  });

  test('JSON이 아닌 오류 응답은 기본 메시지로 대체한다', () async {
    final client = ApiClient(
      client: MockClient(
        (request) async => http.Response('<html>Bad Gateway</html>', 502),
      ),
    );
    await expectLater(
      client.fetchSemesters(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.message, 'message', '학기 정보를 불러오지 못했습니다.'),
      ),
    );
  });

  test('상태를 바꾸는 요청에는 CSRF 토큰을 싣는다', () async {
    String? sentToken;
    final client = ApiClient(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/auth/csrf/')) {
          return jsonResponse({'csrfToken': 'token-123'}, 200);
        }
        sentToken = request.headers['X-CSRFToken'];
        return jsonResponse({'message': '비밀번호가 변경되었습니다.'}, 200);
      }),
    );
    await client.changePassword('Kuics-new-2026!');
    expect(sentToken, 'token-123');
  });
}
