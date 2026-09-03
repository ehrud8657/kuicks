from rest_framework.permissions import BasePermission
from apps.accounts.models import Member

class IsAssignedLeaderOrAdmin(BasePermission):
    def has_object_permission(self, request, view, obj):
        study = obj.study if hasattr(obj, "study") else obj
        return request.user.is_authenticated and (
            request.user.role == Member.Role.ADMIN or study.leader_id == request.user.pk
        )

