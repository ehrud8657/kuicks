from django.contrib.auth import authenticate, login, logout, update_session_auth_hash
from django.contrib.auth.password_validation import validate_password
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from .serializers import MemberSerializer

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
        validate_password(password, request.user)
        request.user.set_password(password)
        request.user.must_change_password = False
        request.user.save(update_fields=("password", "must_change_password"))
        update_session_auth_hash(request, request.user)
        return Response({"message": "비밀번호가 변경되었습니다."})

class MeView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    def get(self, request):
        return Response(MemberSerializer(request.user).data)

