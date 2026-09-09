from django.contrib import admin
from .models import AssignmentSubmit, Participation, Semester, Study

class ParticipationInline(admin.TabularInline):
    model = Participation
    extra = 0
    autocomplete_fields = ("member",)

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
    inlines = (ParticipationInline,)

    @admin.display(description="스터디장", ordering="leader__name")
    def leader_display(self, obj):
        return obj.leader.name if obj.leader else "미정"

@admin.register(Participation)
class ParticipationAdmin(admin.ModelAdmin):
    list_display = ("member", "study", "status", "updated_at")
    list_filter = ("status", "study__semester")
    search_fields = ("member__name", "member__student_id", "study__title")

admin.site.register(AssignmentSubmit)

