from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import Member

@admin.register(Member)
class MemberAdmin(UserAdmin):
    ordering = ("student_id",)
    list_display = ("student_id", "name", "role", "must_change_password", "is_active")
    list_filter = ("role", "must_change_password", "is_active")
    search_fields = ("student_id", "name")
    fieldsets = (
        (None, {"fields": ("student_id", "password")}),
        ("회원 정보", {"fields": ("name", "role", "must_change_password")}),
        ("권한", {"fields": ("is_active", "is_staff", "is_superuser", "groups", "user_permissions")}),
        ("기록", {"fields": ("last_login", "date_joined")}),
    )
    add_fieldsets = ((None, {"classes": ("wide",), "fields": ("student_id", "name", "role", "password1", "password2")}),)

