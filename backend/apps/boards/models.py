from django.conf import settings
from django.db import models
from django.utils import timezone

class Post(models.Model):
    class Category(models.TextChoices):
        NOTICE = "notice", "공지사항"
        RECRUIT = "recruit", "모집공고"
    category = models.CharField(max_length=10, choices=Category.choices)
    title = models.CharField(max_length=200)
    content = models.TextField()
    author = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="posts")
    is_pinned = models.BooleanField(default=False)
    # 기본값을 지금으로 두어, 그냥 저장하면 바로 게시된다.
    # 비우면 비공개(임시 저장), 미래 시각으로 두면 예약 게시가 된다.
    published_at = models.DateTimeField(
        default=timezone.now,
        null=True,
        blank=True,
        help_text="비워두면 사이트에 공개되지 않습니다. 미래 시각으로 두면 그때부터 공개됩니다.",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    def __str__(self): return self.title
    class Meta:
        ordering = ("-is_pinned", "-published_at", "-created_at")

