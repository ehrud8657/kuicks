from django.contrib.auth.models import AnonymousUser
from django.http import HttpResponse
from django.middleware.csrf import get_token
from django.utils.html import escape

# 초기 비밀번호를 바꾸기 전에도 써야 하는 API.
# /api/me/는 프론트가 세션을 복원하면서 "변경 필요" 상태를 알아야 해서 연다.
PASSWORD_CHANGE_EXEMPT_API_PATHS = frozenset(
    {
        "/api/auth/csrf/",
        "/api/auth/login/",
        "/api/auth/logout/",
        "/api/auth/change-password/",
        "/api/me/",
    }
)
PASSWORD_CHANGE_EXEMPT_ADMIN_PATHS = frozenset({"/admin/logout/"})


class PasswordChangeRequiredMiddleware:
    """초기 비밀번호를 바꾸지 않은 회원이 API와 Admin을 쓰지 못하게 서버에서 막는다.

    프론트의 강제 변경 창만으로는 API를 직접 호출하는 경우를 막을 수 없다.

    - /api/: 허용 목록 밖의 요청은 비로그인 사용자로 취급한다. 공개 API(학기, 게시판)는
      그대로 열리고, 로그인이 필요한 API는 password_change_required 오류가 된다
      (config.exceptions.api_exception_handler).
    - /admin/: 로그아웃을 제외하고 안내 페이지를 보여준다.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        path = request.path_info
        is_api = path.startswith("/api/")
        is_admin = path.startswith("/admin/")
        if (is_api or is_admin) and self._must_change_password(request):
            if is_api and path not in PASSWORD_CHANGE_EXEMPT_API_PATHS:
                request.user = AnonymousUser()
                request.password_change_required = True
            elif is_admin and path not in PASSWORD_CHANGE_EXEMPT_ADMIN_PATHS:
                return self._admin_blocked(request)
        return self.get_response(request)

    @staticmethod
    def _must_change_password(request):
        user = getattr(request, "user", None)
        return bool(user and user.is_authenticated and user.must_change_password)

    @staticmethod
    def _admin_blocked(request):
        name = escape(request.user.name)
        token = get_token(request)
        html = f"""<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>비밀번호 변경 필요 | KUICS</title>
<style>
  body {{ font-family: sans-serif; max-width: 560px; margin: 80px auto; padding: 0 16px; color: #071B33; line-height: 1.6; }}
  a {{ color: #B31B34; }}
  button {{ font-size: 15px; padding: 8px 16px; margin-top: 8px; cursor: pointer; }}
</style>
</head>
<body>
<h1>비밀번호를 먼저 변경해주세요</h1>
<p>{name}님은 아직 초기 비밀번호를 사용하고 있습니다. 관리자 페이지는 비밀번호를 변경한 뒤 이용할 수 있습니다.</p>
<p><a href="/">홈페이지로 이동해 비밀번호 변경하기</a></p>
<form method="post" action="/admin/logout/">
  <input type="hidden" name="csrfmiddlewaretoken" value="{token}">
  <button type="submit">로그아웃</button>
</form>
</body>
</html>"""
        return HttpResponse(html, status=403)
