from rest_framework import exceptions, status
from rest_framework.response import Response
from rest_framework.views import exception_handler

PASSWORD_CHANGE_REQUIRED = {
    "code": "password_change_required",
    "message": "초기 비밀번호를 변경한 뒤 이용할 수 있습니다.",
    "fields": None,
}


def _first_message(data):
    """ValidationError 상세(dict/list 중첩)에서 화면에 보여줄 첫 메시지를 꺼낸다."""
    if isinstance(data, dict):
        values = data.values()
    elif isinstance(data, (list, tuple)):
        values = data
    else:
        return str(data)
    for value in values:
        message = _first_message(value)
        if message:
            return message
    return ""


def api_exception_handler(exc, context):
    """모든 API 오류 응답을 {"code", "message", "fields"} 형식으로 통일한다.

    - code: 프론트가 분기할 때 쓰는 식별자 (not_authenticated, permission_denied, invalid ...)
    - message: 사용자에게 그대로 보여줄 수 있는 문장
    - fields: 입력값 오류일 때만 {필드명: [메시지]}
    """
    request = getattr(context.get("request"), "_request", None)
    if getattr(request, "password_change_required", False) and isinstance(
        exc, (exceptions.NotAuthenticated, exceptions.AuthenticationFailed, exceptions.PermissionDenied)
    ):
        return Response(PASSWORD_CHANGE_REQUIRED, status=status.HTTP_403_FORBIDDEN)

    response = exception_handler(exc, context)
    if response is None:
        return None

    if isinstance(exc, exceptions.ValidationError):
        data = response.data
        response.data = {
            "code": "invalid",
            "message": _first_message(data) or "입력값을 확인해주세요.",
            "fields": data if isinstance(data, dict) else None,
        }
        return response

    detail = response.data.get("detail") if isinstance(response.data, dict) else None
    response.data = {
        "code": getattr(detail, "code", None) or getattr(exc, "default_code", "error"),
        "message": str(detail) if detail is not None else str(exc),
        "fields": None,
    }
    return response
