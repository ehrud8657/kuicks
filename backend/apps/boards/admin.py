from django.contrib import admin
from .models import Post

@admin.register(Post)
class PostAdmin(admin.ModelAdmin):
    list_display = ("title", "category", "author", "is_pinned", "published_at")
    list_filter = ("category", "is_pinned")
    search_fields = ("title", "content")
    autocomplete_fields = ("author",)

