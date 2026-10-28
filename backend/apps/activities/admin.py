from django.contrib import admin
from django.urls import reverse
from django.utils.html import format_html

from .models import Activity, ActivityMember, Material, MaterialFile, Tag


@admin.register(Tag)
class TagAdmin(admin.ModelAdmin):
    search_fields = ("name",)


class ActivityMemberInline(admin.TabularInline):
    model = ActivityMember
    extra = 1
    fields = ("member", "name", "role")
    autocomplete_fields = ("member",)
    verbose_name_plural = "참여자 (사이트 계정을 연결한 정회원 이상만 사이트에서 자료를 올릴 수 있습니다)"


class MaterialInline(admin.TabularInline):
    """활동 화면에서는 자료 목록만 보여주고, 파일은 자료 화면에서 붙인다."""

    model = Material
    extra = 0
    fields = ("stage", "title", "date", "author_name", "file_count", "edit_link")
    readonly_fields = ("author_name", "file_count", "edit_link")
    show_change_link = False

    @admin.display(description="첨부")
    def file_count(self, material):
        count = material.files.count() if material.pk else 0
        return f"{count}개" if count else "-"

    @admin.display(description="")
    def edit_link(self, material):
        if not material.pk:
            return "저장한 뒤 파일을 붙일 수 있습니다."
        return format_html(
            '<a href="{}">설명·파일 편집</a>', reverse("admin:activities_material_change", args=[material.pk])
        )


@admin.register(Activity)
class ActivityAdmin(admin.ModelAdmin):
    list_display = ("title", "kind", "semester", "status", "is_published", "material_count")
    list_filter = ("kind", "semester", "status", "is_published", "tags")
    search_fields = ("title", "topic", "summary")
    filter_horizontal = ("tags",)
    inlines = (ActivityMemberInline, MaterialInline)
    fieldsets = (
        (None, {"fields": ("kind", "semester", "title", "status", "is_published")}),
        ("소개", {"fields": ("topic", "summary", "description", "tags", "start_date", "end_date")}),
        ("대회·행사일 때만", {"fields": ("result", "team_name", "location")}),
    )

    def get_queryset(self, request):
        return super().get_queryset(request).select_related("semester").prefetch_related("materials")

    @admin.display(description="자료")
    def material_count(self, activity):
        count = len(activity.materials.all())
        return f"{count}개" if count else "-"


class MaterialFileInline(admin.TabularInline):
    model = MaterialFile
    extra = 1
    fields = ("file", "preview", "original_name", "size")
    readonly_fields = ("preview", "original_name", "size")
    verbose_name_plural = "첨부파일 (형식 무관, 없어도 됩니다)"

    @admin.display(description="미리보기")
    def preview(self, attachment):
        if not attachment.pk:
            return "저장하면 표시됩니다."
        if attachment.is_image:
            return format_html(
                '<img src="{}" style="max-height:80px;max-width:140px;border-radius:4px" />',
                reverse("activity-file", args=[attachment.pk]),
            )
        return attachment.content_type or "-"


@admin.register(Material)
class MaterialAdmin(admin.ModelAdmin):
    list_display = ("title", "activity", "stage", "date", "author_name")
    list_filter = ("stage", "activity__kind", "activity__semester")
    search_fields = ("title", "description", "activity__title")
    autocomplete_fields = ("activity", "author")
    inlines = (MaterialFileInline,)
    fields = ("activity", "stage", "title", "description", "date", "author", "author_name")

    def save_model(self, request, obj, form, change):
        # Admin에서 새로 올리면 올린 사람을 운영진 본인으로 채운다.
        if not change and not obj.author_id:
            obj.author = request.user
        super().save_model(request, obj, form, change)
