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
    list_display = ("title", "semester", "leader", "updated_at")
    list_filter = ("semester",)
    search_fields = ("title", "leader__name", "leader__student_id")
    autocomplete_fields = ("leader",)
    inlines = (ParticipationInline,)

@admin.register(Participation)
class ParticipationAdmin(admin.ModelAdmin):
    list_display = ("member", "study", "status", "updated_at")
    list_filter = ("status", "study__semester")
    search_fields = ("member__name", "member__student_id", "study__title")

admin.site.register(AssignmentSubmit)

