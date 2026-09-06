import re

from django.conf import settings
from rest_framework import exceptions
from rest_framework.authentication import CSRFCheck, SessionAuthentication

_LOCAL_ORIGIN_RE = re.compile(r"^https?://(localhost|127\.0\.0\.1):\d+$")


class DevFriendlyCSRFCheck(CSRFCheck):
    """DEBUG 환경에서는 매번 임의 포트로 뜨는 로컬 프론트(Flutter web)의 Origin을 신뢰한다.

    DRF의 SessionAuthentication은 django-cors-headers와 무관하게 이 클래스를 통해
    자체적으로 CSRF Origin 검증을 하므로, CORS 쪽 설정만 고쳐서는 해결되지 않는다.
    """

    def _origin_verified(self, request):
        if settings.DEBUG:
            origin = request.META.get("HTTP_ORIGIN", "")
            if _LOCAL_ORIGIN_RE.match(origin):
                return True
        return super()._origin_verified(request)


class LocalDevSessionAuthentication(SessionAuthentication):
    def enforce_csrf(self, request):
        def dummy_get_response(request):
            return None

        check = DevFriendlyCSRFCheck(dummy_get_response)
        check.process_request(request)
        reason = check.process_view(request, None, (), {})
        if reason:
            raise exceptions.PermissionDenied("CSRF Failed: %s" % reason)
