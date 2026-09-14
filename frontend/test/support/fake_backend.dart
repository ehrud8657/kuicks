import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kuics_frontend/api_client.dart';
import 'package:kuics_frontend/theme.dart';

typedef RouteHandler = Object? Function(http.Request request);

/// 경로별로 응답을 정해두는 가짜 API 서버. 보낸 요청을 기록해 검사할 수 있다.
class FakeBackend {
  final _routes = <String, (int, RouteHandler)>{};
  final requests = <http.Request>[];

  void on(String method, String path, RouteHandler handler,
          {int status = 200}) =>
      _routes['$method $path'] = (status, handler);

  List<http.Request> sent(String method, String path) => requests
      .where((request) => request.method == method && request.url.path == path)
      .toList();

  Map<String, dynamic> lastJson(String method, String path) =>
      jsonDecode(utf8.decode(sent(method, path).last.bodyBytes))
          as Map<String, dynamic>;

  MockClient get client => MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/auth/csrf/')) {
          return jsonResponse({'csrfToken': 'test-token'});
        }
        final route = _routes['${request.method} ${request.url.path}'];
        if (route == null) {
          return jsonResponse(
            {
              'code': 'not_found',
              'message': '테스트에 없는 경로: ${request.method} ${request.url.path}',
              'fields': null,
            },
            status: 404,
          );
        }
        final (status, handler) = route;
        // 응답을 늦춰야 하는 테스트는 Future를 돌려줄 수 있다.
        var body = handler(request);
        if (body is Future) body = await body;
        return body is http.Response
            ? body
            : jsonResponse(body, status: status);
      });

  /// 앱 전체가 이 가짜 서버를 쓰게 한다.
  void install() => ApiClient.instance = ApiClient(client: client);
}

http.Response jsonResponse(Object? body, {int status = 200}) =>
    http.Response.bytes(
      body == null ? const [] : utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> decodeBody(http.Request request) =>
    jsonDecode(utf8.decode(request.bodyBytes)) as Map<String, dynamic>;

/// 실제 앱과 같은 테마·한국어 설정으로 화면 하나를 띄운다.
Widget testApp(Widget home) => Builder(
      builder: (context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(Theme.of(context).textTheme),
        locale: const Locale('ko'),
        supportedLocales: const [Locale('ko'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: home,
      ),
    );
