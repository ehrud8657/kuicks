from django.conf import settings
from django.db import models

class Post(models.Model):
    class Category(models.TextChoices):
        NOTICE = "notice", "공지사항"
        RECRUIT = "recruit", "모집공고"
    category = models.CharField(max_length=10, choices=Category.choices)
    title = models.CharField(max_length=200)
    content = models.TextField()
    author = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="posts")
    is_pinned = models.BooleanField(default=False)
    published_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    def __str__(self): return self.title
    class Meta:
        ordering = ("-is_pinned", "-published_at", "-created_at")

