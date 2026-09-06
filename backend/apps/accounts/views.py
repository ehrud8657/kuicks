from django.contrib.auth import authenticate, login, logout, update_session_auth_hash
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from django.middleware.csrf import get_token
from django.utils.decorators import method_decorator
from django.views.decorators.csrf import ensure_csrf_cookie
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from .serializers import MemberSerializer

class CsrfTokenView(APIView):
    permission_classes = [permissions.AllowAny]

    @method_decorator(ensure_csrf_cookie)
    def get(self, request):
        # 세션 쿠키 인증 방식이라 로그인 POST 전에 csrftoken 쿠키를 먼저 심어줘야 한다.
        # 프론트는 이 응답의 값을 X-CSRFToken 헤더에 그대로 실어 보내면 된다.
        return Response({"csrfToken": get_token(request)})

class LoginView(APIView):
    def post(self, request):
        user = authenticate(request, student_id=request.data.get("student_id"), password=request.data.get("password"))
        if user is None:
            return Response({"code": "invalid_credentials", "message": "학번 또는 비밀번호를 확인해주세요.", "fields": None}, status=status.HTTP_400_BAD_REQUEST)
        login(request, user)
        return Response(MemberSerializer(user).data)

class LogoutView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    def post(self, request):
        logout(request)
        return Response(status=status.HTTP_204_NO_CONTENT)

class ChangePasswordView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    def post(self, request):
        password = request.data.get("new_password", "")
        try:
            validate_password(password, request.user)
        except DjangoValidationError as exc:
            return Response(
                {"code": "invalid_password", "message": " ".join(exc.messages), "fields": {"new_password": exc.messages}},
                status=status.HTTP_400_BAD_REQUEST,
            )
        request.user.set_password(password)
        request.user.must_change_password = False
        request.user.save(update_fields=("password", "must_change_password"))
        update_session_auth_hash(request, request.user)
        return Response({"message": "비밀번호가 변경되었습니다."})

class MeView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    def get(self, request):
        return Response(MemberSerializer(request.user).data)

