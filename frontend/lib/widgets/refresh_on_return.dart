import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// 하위 화면(예: /manage → /manage/studies/3/...)에서 이 화면으로 돌아오면 [onReturn]을 부른다.
///
/// 앱 안의 ← 버튼, 브라우저 뒤로가기, 주소를 바로 열어 들어온 경우 모두 같은 방식으로
/// 동작하도록, 화면을 연 쪽에서 결과를 기다리지 않고 경로 변화로 판단한다.
mixin RefreshOnReturn<T extends StatefulWidget> on State<T> {
  GoRouter? _router;
  String? _lastPath;

  /// 이 화면 자신의 경로인지. 탭처럼 경로가 바뀌는 화면은 여러 경로를 true로 돌려준다.
  bool isOwnPath(String path);

  /// 하위 화면에서 돌아왔을 때 할 일 (보통 목록을 다시 불러온다).
  void onReturn();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (router == null || identical(router, _router)) return;
    _router?.routerDelegate.removeListener(_onRouteChanged);
    _router = router;
    _lastPath = _currentPath;
    router.routerDelegate.addListener(_onRouteChanged);
  }

  // currentConfiguration.uri는 push로 연 화면을 반영하지 않으므로, 맨 위 화면 기준인 state를 쓴다.
  String? get _currentPath {
    final router = _router;
    if (router == null || router.routerDelegate.currentConfiguration.isEmpty) {
      return null;
    }
    return router.state.uri.path;
  }

  void _onRouteChanged() {
    final path = _currentPath;
    if (path == null || !mounted) return;
    final last = _lastPath;
    _lastPath = path;
    if (last != null && isOwnPath(path) && last.startsWith('$path/')) {
      onReturn();
    }
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }
}
