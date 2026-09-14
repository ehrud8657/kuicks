import 'package:flutter/material.dart';

import 'api_client.dart';
import 'models.dart';
import 'widgets/auth_dialogs.dart';

/// 로그인 상태와 로그인·로그아웃·비밀번호 변경 창을 앱 전체에서 함께 쓴다.
///
/// 경로마다 화면이 따로 만들어지므로 로그인 정보는 셸이 아니라 여기에 둔다.
class AuthController extends ChangeNotifier {
  AuthController({required this.navigatorKey}) {
    ApiClient.passwordChangeRequired.addListener(_onPasswordChangeRequired);
    ApiClient.loginRequired.addListener(_onLoginRequired);
  }

  bool _loggingOut = false;

  /// 로그인한 줄 알았는데 서버가 로그인이 필요하다고 하면(다른 탭에서 로그아웃, 세션 만료)
  /// 로그인 상태를 비우고 로그인 창을 띄운다.
  void _onLoginRequired() {
    if (_member == null || _loggingOut) return;
    _set(() => _member = null);
    showLogin(notice: ApiClient.loginRequiredMessage);
  }

  /// 창(다이얼로그)을 띄울 때 쓰는 최상위 Navigator.
  final GlobalKey<NavigatorState> navigatorKey;

  /// 로그아웃한 뒤 할 일 (앱에서 홈으로 이동하도록 연결한다).
  VoidCallback? onLoggedOut;

  Member? _member;
  bool _restoring = true;
  bool _passwordDialogOpen = false;
  bool _disposed = false;

  /// 강제 비밀번호 변경을 마칠 때마다 1씩 늘어난다.
  /// 변경 전에 서버가 거절한 화면들이 이 값을 보고 새로 불러온다.
  int _passwordVersion = 0;
  int get passwordVersion => _passwordVersion;

  Member? get member => _member;

  /// 첫 화면에서 세션을 확인하는 중이면 true.
  bool get restoring => _restoring;
  bool get loggedIn => _member != null;

  /// 스터디 관리 메뉴를 보여줄 등급. 실제 권한은 서버가 다시 검사한다.
  bool get canManage => _member?.role.canManageStudies ?? false;

  BuildContext? get _context => navigatorKey.currentContext;

  void _set(VoidCallback change) {
    if (_disposed) return;
    change();
    notifyListeners();
  }

  Future<void> restore() async {
    try {
      final member = await ApiClient.instance.fetchMe();
      _set(() {
        _member = member;
        _restoring = false;
      });
      if (member != null && member.mustChangePassword) {
        await promptChangePassword(forced: true);
      }
    } catch (_) {
      _set(() => _restoring = false);
    }
  }

  Future<void> showLogin({String? notice}) async {
    final context = _context;
    if (context == null) return;
    final member = await showDialog<Member>(
      context: context,
      builder: (context) => LoginDialog(notice: notice),
    );
    if (member == null) return;
    _set(() => _member = member);
    if (member.mustChangePassword) await promptChangePassword(forced: true);
  }

  Future<void> logout() async {
    _loggingOut = true;
    try {
      await ApiClient.instance.logout();
    } catch (_) {
      // 세션이 이미 끊겨있어도 로컬 상태는 정리한다.
    } finally {
      _loggingOut = false;
    }
    _set(() => _member = null);
    onLoggedOut?.call();
  }

  /// 메뉴 서랍에서 로그인하면 로그인 후 홈을 보여준다.
  Future<void> showLoginThenHome() async {
    await showLogin();
    if (loggedIn) onLoggedIn?.call();
  }

  /// 서랍 로그인 성공 뒤 할 일 (앱에서 홈으로 이동하도록 연결한다).
  VoidCallback? onLoggedIn;

  Future<void> promptChangePassword({required bool forced}) async {
    final context = _context;
    // 세션 복원과 API 오류가 동시에 요청해도 창은 하나만 띄운다.
    if (context == null || _passwordDialogOpen) return;
    _passwordDialogOpen = true;
    final result = await showDialog<PasswordDialogResult>(
      barrierDismissible: !forced,
      context: context,
      builder: (context) => ChangePasswordDialog(forced: forced),
    );
    _passwordDialogOpen = false;
    switch (result) {
      case PasswordDialogResult.changed:
        final member = _member;
        if (member != null) {
          _set(() {
            if (member.mustChangePassword) _passwordVersion++;
            _member = member.copyWith(mustChangePassword: false);
          });
        }
      case PasswordDialogResult.logout:
        await logout();
      case null:
        break;
    }
  }

  /// 어떤 화면의 API 호출이든 서버가 password_change_required로 막으면 강제 변경 창을 띄운다.
  void _onPasswordChangeRequired() {
    final member = _member;
    if (member == null) return;
    _set(() => _member = member.copyWith(mustChangePassword: true));
    promptChangePassword(forced: true);
  }

  @override
  void dispose() {
    _disposed = true;
    ApiClient.passwordChangeRequired.removeListener(_onPasswordChangeRequired);
    ApiClient.loginRequired.removeListener(_onLoginRequired);
    super.dispose();
  }
}

/// 하위 위젯에서 [AuthController]를 찾는다. 로그인 상태가 바뀌면 다시 그린다.
class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({
    super.key,
    required AuthController controller,
    required super.child,
  }) : super(notifier: controller);

  static AuthController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthScope>()!.notifier!;
}
