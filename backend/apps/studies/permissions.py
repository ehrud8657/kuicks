from rest_framework.permissions import BasePermission

from apps.accounts.models import Member


def is_admin(user):
    return user.is_authenticated and user.role == Member.Role.ADMIN


def can_manage_study(user, study):
    """운영진은 모든 스터디, 스터디장은 본인이 담당하는 스터디만 관리한다."""
    return user.is_authenticated and (user.role == Member.Role.ADMIN or study.leader_id == user.pk)


def managed_studies(user):
    """관리할 수 있는 스터디 목록."""
    from .models import Study

    queryset = Study.objects.all()
    return queryset if is_admin(user) else queryset.filter(leader_id=user.pk)


def study_of(obj):
    """관리 대상 객체(스터디·참여·회차·과제·제출)가 속한 스터디."""
    from .models import Study

    if isinstance(obj, Study):
        return obj
    if hasattr(obj, "study"):
        return obj.study
    if hasattr(obj, "assignment"):
        return obj.assignment.study
    return obj.session.study


class IsStudyManager(BasePermission):
    """스터디 관리 API 접근 권한.

    등급(role) 값이 아니라 실제 담당 스터디가 있는지로 스터디장을 판단한다.
    CSV로 등급만 스터디장으로 바뀐 회원이 관리 화면에 들어오지 못하게 하기 위함이다.
    """

    message = "스터디장 또는 운영진만 이용할 수 있습니다."

    def has_permission(self, request, view):
        user = request.user
        if not user.is_authenticated:
            return False
        return is_admin(user) or managed_studies(user).exists()

    def has_object_permission(self, request, view, obj):
        if can_manage_study(request.user, study_of(obj)):
            return True
        self.message = "담당하는 스터디만 관리할 수 있습니다."
        return False


class IsAssignedLeaderOrAdmin(BasePermission):
    message = "담당하는 스터디만 관리할 수 있습니다."

    def has_object_permission(self, request, view, obj):
        return can_manage_study(request.user, study_of(obj))
