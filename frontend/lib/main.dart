import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

import 'auth.dart';
import 'router.dart';
import 'routes.dart';
import 'theme.dart';

void main() {
  // 주소를 /#/study 대신 /study 형태로 쓴다.
  // 배포 서버는 없는 경로도 index.html을 돌려줘야 한다 (nginx try_files, vercel rewrites에 설정됨).
  usePathUrlStrategy();
  runApp(const KuicsApp());
}

class KuicsApp extends StatefulWidget {
  const KuicsApp({super.key, this.initialLocation});

  /// 테스트에서 특정 주소로 시작할 때 쓴다. 웹에서는 브라우저 주소가 우선한다.
  final String? initialLocation;

  @override
  State<KuicsApp> createState() => _KuicsAppState();
}

class _KuicsAppState extends State<KuicsApp> {
  final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  late final AuthController _auth =
      AuthController(navigatorKey: _rootNavigatorKey);
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    // push로 연 화면도 주소창과 방문 기록에 남겨, 브라우저 뒤로가기가 앱 안에서 동작하게 한다.
    GoRouter.optionURLReflectsImperativeAPIs = true;
    _router = createRouter(
      rootNavigatorKey: _rootNavigatorKey,
      initialLocation: widget.initialLocation ?? AppRoutes.home,
    );
    // 로그아웃하거나 서랍 메뉴에서 로그인하면 홈으로 보낸다.
    void goHome() => _router.go(AppRoutes.home);
    _auth.onLoggedOut = goHome;
    _auth.onLoggedIn = goHome;
    _auth.restore();
  }

  @override
  void dispose() {
    _router.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthScope(
        controller: _auth,
        child: MaterialApp.router(
          title: 'KUICS',
          debugShowCheckedModeBanner: false,
          // 날짜·시간 선택창과 기본 버튼 문구를 한국어로 표시한다.
          locale: const Locale('ko'),
          supportedLocales: const [Locale('ko'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: buildAppTheme(Theme.of(context).textTheme),
          routerConfig: _router,
        ),
      );
}
