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
    # is_staff/is_superuser는 Member.save()에서 role 기준으로 항상 재계산되는 파생값이라
    # 관리자 화면에서 직접 체크박스로 건드리지 못하게 읽기 전용으로 노출한다.
    readonly_fields = ("is_staff", "is_superuser", "last_login", "date_joined")
    fieldsets = (
        (None, {"fields": ("student_id", "password")}),
        ("회원 정보", {"fields": ("name", "role", "must_change_password")}),
        ("권한 (role에 따라 자동 결정됨)", {"fields": ("is_active", "is_staff", "is_superuser", "groups", "user_permissions")}),
        ("기록", {"fields": ("last_login", "date_joined")}),
    )
    add_fieldsets = (
        (None, {
            "classes": ("wide",),
            "fields": ("student_id", "name", "role"),
            "description": "초기 비밀번호는 'kuics!학번'으로 자동 설정됩니다. (예: 학번 2026320044 → kuics!2026320044)",
        }),
    )

    def _bulk_set_role(self, request, queryset, role, message):
        count = 0
        for member in queryset:
            member.role = role
            member.save()
            count += 1
        self.message_user(request, f"{count}명을 {message}")

    @admin.action(description="선택한 회원을 운영진으로 지정")
    def make_admin(self, request, queryset):
        self._bulk_set_role(request, queryset, Member.Role.ADMIN, "운영진으로 지정했습니다.")

    @admin.action(description="선택한 회원의 운영진 권한 해제 (정회원으로)")
    def remove_admin(self, request, queryset):
        self._bulk_set_role(request, queryset, Member.Role.MEMBER, "정회원으로 변경했습니다.")

