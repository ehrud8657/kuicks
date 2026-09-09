import 'package:http/browser_client.dart' as browser;
import 'package:http/http.dart' as http;

/// 웹(브라우저)에서 쓰는 클라이언트.
///
/// 세션 쿠키 기반 인증이라 cross-origin 요청에도 쿠키가 실려야 한다.
/// (기본 http.Client는 브라우저에서 withCredentials가 꺼져있어 쿠키를 안 보낸다.)
http.Client createHttpClient() => browser.BrowserClient()..withCredentials = true;
