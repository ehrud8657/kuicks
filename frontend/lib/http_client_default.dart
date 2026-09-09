import 'package:http/http.dart' as http;

/// 브라우저가 아닌 환경(단위 테스트 등)에서 쓰는 기본 클라이언트.
///
/// 쿠키 처리는 브라우저가 담당하므로 여기서는 별도 설정이 필요 없다.
http.Client createHttpClient() => http.Client();
