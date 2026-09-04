from django import forms
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import Member

INITIAL_PASSWORD_PREFIX = "kuics!"


class MemberAddForm(forms.ModelForm):
    class Meta:
        model = Member
        fields = ("student_id", "name", "role")

    def save(self, commit=True):
        member = super().save(commit=False)
        member.set_password(f"{INITIAL_PASSWORD_PREFIX}{member.student_id}")
        if commit:
            member.save()
        return member


@admin.register(Member)
class MemberAdmin(UserAdmin):
    add_form = MemberAddForm
    ordering = ("student_id",)
    list_display = ("student_id", "name", "role", "must_change_password", "is_active")
    list_filter = ("role", "must_change_password", "is_active")
    search_fields = ("student_id", "name")
    actions = ("make_admin", "remove_admin")
    fieldsets = (
        (None, {"fields": ("student_id", "password")}),
        ("회원 정보", {"fields": ("name", "role", "must_change_password")}),
        ("권한", {"fields": ("is_active", "is_staff", "is_superuser", "groups", "user_permissions")}),
        ("기록", {"fields": ("last_login", "date_joined")}),
    )
    add_fieldsets = (
        (None, {
            "classes": ("wide",),
            "fields": ("student_id", "name", "role"),
            "description": "초기 비밀번호는 'kuics!학번'으로 자동 설정됩니다. (예: 학번 2026320044 → kuics!2026320044)",
        }),
    )

    @admin.action(description="선택한 회원을 운영진으로 지정")
    def make_admin(self, request, queryset):
        updated = queryset.update(role=Member.Role.ADMIN, is_staff=True, is_superuser=True)
        self.message_user(request, f"{updated}명을 운영진으로 지정했습니다.")

    @admin.action(description="선택한 회원의 운영진 권한 해제 (일반 회원으로)")
    def remove_admin(self, request, queryset):
        updated = queryset.update(role=Member.Role.MEMBER, is_staff=False, is_superuser=False)
        self.message_user(request, f"{updated}명의 운영진 권한을 해제했습니다.")

