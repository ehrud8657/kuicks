import uuid
from pathlib import Path

from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models
from django.db.models.signals import post_delete
from django.dispatch import receiver
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


# 게시글 첨부로 허용하는 확장자. 실행 파일과 압축파일은 받지 않는다.
# (공지에 필요한 것은 사진과 문서이고, 실행 파일은 그대로 배포하면 위험하다.)
ALLOWED_ATTACHMENT_EXTENSIONS = {
    ".jpg", ".jpeg", ".png", ".gif", ".webp", ".svg",
    ".pdf", ".hwp", ".hwpx", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx", ".txt", ".csv",
}

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".webp", ".svg"}

_CONTENT_TYPES = {
    ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png",
    ".gif": "image/gif", ".webp": "image/webp", ".svg": "image/svg+xml",
    ".pdf": "application/pdf", ".txt": "text/plain; charset=utf-8", ".csv": "text/csv; charset=utf-8",
    ".hwp": "application/x-hwp", ".hwpx": "application/haansofthwpx",
    ".doc": "application/msword",
    ".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    ".xls": "application/vnd.ms-excel",
    ".xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    ".ppt": "application/vnd.ms-powerpoint",
    ".pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
}


def attachment_upload_to(instance, filename):
    """첨부 저장 경로. 원본 파일명은 DB에만 두고 경로에는 추측하기 어려운 이름을 쓴다.

    한글 파일명을 그대로 경로에 쓰면 서버 파일시스템 인코딩에 따라 깨질 수 있고,
    같은 이름을 다시 올렸을 때 서로 덮어쓰는 문제도 생긴다.
    """
    suffix = Path(filename).suffix.lower()
    return f"board/{instance.post_id}/{uuid.uuid4().hex}{suffix}"


class PostAttachment(models.Model):
    """게시글 첨부파일. 사진은 본문 아래에 바로 보이고, 문서는 내려받기 링크로 나간다.

    게시글당 개수 제한은 두지 않는다. 첨부가 없는 글이 기본이다.
    """

    post = models.ForeignKey(Post, on_delete=models.CASCADE, related_name="attachments")
    file = models.FileField("파일", upload_to=attachment_upload_to, max_length=255)
    original_name = models.CharField("원본 파일명", max_length=255, blank=True)
    content_type = models.CharField("종류", max_length=120, blank=True)
    size = models.PositiveBigIntegerField("크기(바이트)", default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    @property
    def extension(self):
        return Path(self.original_name or self.file.name or "").suffix.lower()

    @property
    def is_image(self):
        return self.extension in IMAGE_EXTENSIONS

    def clean(self):
        # Admin에서 저장하기 전에 걸러, 용량 초과 파일이 디스크에 남지 않게 한다.
        uploaded = self.file
        if not uploaded:
            return
        suffix = Path(getattr(uploaded, "name", "") or "").suffix.lower()
        if suffix not in ALLOWED_ATTACHMENT_EXTENSIONS:
            allowed = ", ".join(sorted(ALLOWED_ATTACHMENT_EXTENSIONS))
            raise ValidationError({"file": f"올릴 수 없는 형식입니다. 가능한 형식: {allowed}"})
        size = getattr(uploaded, "size", None)
        limit = settings.BOARD_ATTACHMENT_MAX_BYTES
        if size and size > limit:
            raise ValidationError(
                {"file": f"파일이 너무 큽니다. {limit // (1024 * 1024)}MB 이하만 올릴 수 있습니다."}
            )

    def save(self, *args, **kwargs):
        # 원본 파일명·크기·종류는 업로드 시점에만 알 수 있으므로 저장할 때 채운다.
        uploaded_name = getattr(self.file, "name", "") or ""
        if not self.original_name:
            self.original_name = Path(uploaded_name).name
        if not self.size:
            self.size = getattr(self.file, "size", 0) or 0
        if not self.content_type:
            suffix = Path(self.original_name).suffix.lower()
            self.content_type = _CONTENT_TYPES.get(suffix, "application/octet-stream")
        super().save(*args, **kwargs)

    def __str__(self):
        return self.original_name or self.file.name

    class Meta:
        ordering = ("id",)
        verbose_name = "첨부파일"
        verbose_name_plural = "첨부파일"


@receiver(post_delete, sender=PostAttachment)
def _delete_attachment_file(sender, instance, **kwargs):
    """첨부 기록을 지우면 실제 파일도 지운다.

    게시글을 통째로 지울 때도 CASCADE로 이 신호가 돌아, 쓰지 않는 파일이
    디스크에 쌓이지 않는다. save=False로 지워야 이미 사라진 행을 다시 저장하지 않는다.
    """
    if instance.file:
        instance.file.delete(save=False)
