from django.contrib import admin
from django.urls import reverse
from django.utils.html import format_html

from .models import Post, PostAttachment


class PostAttachmentInline(admin.TabularInline):
    """글을 쓰면서 바로 파일을 붙일 수 있게 게시글 화면 안에 넣는다."""

    model = PostAttachment
    extra = 1
    fields = ("file", "preview", "original_name", "size")
    readonly_fields = ("preview", "original_name", "size")
    verbose_name = "첨부파일"
    verbose_name_plural = "첨부파일 (사진·PDF·문서, 없어도 됩니다)"

    @admin.display(description="미리보기")
    def preview(self, attachment):
        if not attachment.pk:
            return "저장하면 표시됩니다."
        if attachment.is_image:
            return format_html(
                '<img src="{}" style="max-height:80px;max-width:140px;border-radius:4px" />',
                reverse("post-attachment", args=[attachment.pk]),
            )
        return attachment.content_type or "-"


@admin.register(Post)
class PostAdmin(admin.ModelAdmin):
    list_display = ("title", "category", "author", "attachment_count", "is_pinned", "published_at")
    list_filter = ("category", "is_pinned")
    search_fields = ("title", "content")
    autocomplete_fields = ("author",)
    inlines = (PostAttachmentInline,)

    def get_queryset(self, request):
        return super().get_queryset(request).prefetch_related("attachments")

    @admin.display(description="첨부")
    def attachment_count(self, post):
        count = post.attachments.count()
        return f"{count}개" if count else "-"
