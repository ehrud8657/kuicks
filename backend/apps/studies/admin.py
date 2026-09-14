from django.contrib import admin
from django.urls import reverse
from django.utils.html import format_html

from .files import format_size
from .models import Assignment, AssignmentSubmission, Attendance, Participation, Semester, Study, StudySession

class ParticipationInline(admin.TabularInline):
    model = Participation
    extra = 0
    autocomplete_fields = ("member",)

class StudySessionInline(admin.TabularInline):
    model = StudySession
    extra = 0
    fields = ("number", "title", "held_on")

class AssignmentInline(admin.TabularInline):
    model = Assignment
    extra = 0
    fields = ("title", "due_at")
    show_change_link = True

@admin.register(Semester)
class SemesterAdmin(admin.ModelAdmin):
    list_display = ("name", "starts_at", "study_count")
    search_fields = ("name",)
    def study_count(self, obj): return obj.studies.count()

@admin.register(Study)
class StudyAdmin(admin.ModelAdmin):
    list_display = ("title", "semester", "leader_display", "updated_at")
    list_filter = ("semester",)
    search_fields = ("title", "leader__name", "leader__student_id")
    # 등급 제한 없이 검색되므로 정회원도 그대로 스터디장으로 지정할 수 있다.
    # (지정하면 Study.save()가 해당 회원의 등급을 스터디장으로 올린다.)
    autocomplete_fields = ("leader",)
    list_select_related = ("semester", "leader")
    inlines = (ParticipationInline, StudySessionInline, AssignmentInline)

    @admin.display(description="스터디장", ordering="leader__name")
    def leader_display(self, obj):
        return obj.leader.name if obj.leader else "미정"

@admin.register(Participation)
class ParticipationAdmin(admin.ModelAdmin):
    list_display = ("member", "study", "status", "updated_at")
    list_filter = ("status", "study__semester")
    search_fields = ("member__name", "member__student_id", "study__title")


@admin.register(StudySession)
class StudySessionAdmin(admin.ModelAdmin):
    list_display = ("study", "number", "title", "held_on")
    list_filter = ("study__semester",)
    search_fields = ("study__title", "title")
    list_select_related = ("study", "study__semester")


@admin.register(Attendance)
class AttendanceAdmin(admin.ModelAdmin):
    list_display = ("participation", "session", "status", "updated_at")
    list_filter = ("status", "session__study__semester")
    search_fields = ("participation__member__name", "participation__member__student_id", "session__study__title")
    autocomplete_fields = ("participation", "session")
    list_select_related = ("participation__member", "participation__study", "session__study")


@admin.register(Assignment)
class AssignmentAdmin(admin.ModelAdmin):
    list_display = ("title", "study", "due_at", "created_by")
    list_filter = ("study__semester",)
    search_fields = ("title", "study__title")
    readonly_fields = ("created_by", "created_at", "updated_at")
    list_select_related = ("study", "study__semester", "created_by")


@admin.register(AssignmentSubmission)
class AssignmentSubmissionAdmin(admin.ModelAdmin):
    list_display = ("participation", "assignment", "submitted_at", "late_display", "review_status")
    list_filter = ("review_status", "assignment__study__semester")
    search_fields = ("participation__member__name", "participation__member__student_id", "assignment__title")
    list_select_related = ("participation__member", "participation__study", "assignment")
    # 파일은 사이트에서 제출된 것만 다룬다. 경로 대신 권한 검사를 거치는 다운로드 링크를 보여준다.
    fields = (
        "assignment",
        "participation",
        "download_link",
        "size_display",
        "submitted_at",
        "review_status",
        "feedback",
        "reviewed_at",
        "reviewed_by",
    )
    readonly_fields = (
        "assignment",
        "participation",
        "download_link",
        "size_display",
        "submitted_at",
        "reviewed_at",
        "reviewed_by",
    )

    def has_add_permission(self, request):
        return False

    @admin.display(description="파일")
    def download_link(self, obj):
        return format_html('<a href="{}">{}</a>', reverse("submission-download", args=[obj.pk]), obj.original_name)

    @admin.display(description="크기")
    def size_display(self, obj):
        return format_size(obj.size)

    @admin.display(description="지각", boolean=True)
    def late_display(self, obj):
        return obj.is_late
