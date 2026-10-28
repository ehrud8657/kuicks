import uuid
from pathlib import Path

from django.conf import settings
from django.db import models
from django.db.models.signals import post_delete
from django.dispatch import receiver
from django.utils import timezone

from apps.studies.files import content_type_of, is_inline_image, safe_suffix
from apps.studies.models import Semester


class Tag(models.Model):
    """활동 분야 꼬리표(web, pwn …). 자유 입력으로 두면 같은 분야가 여러 이름으로 갈라지므로 운영진이 관리한다."""

    name = models.CharField("이름", max_length=30, unique=True)

    def __str__(self):
        return self.name

    class Meta:
        ordering = ("name",)
        verbose_name = "분야 태그"
        verbose_name_plural = "분야 태그"


class Activity(models.Model):
    """프로젝트·대회·행사 기록 하나. 자료(중간·최종 결과물 등)를 계속 쌓아 아카이브로 남긴다."""

    class Kind(models.TextChoices):
        PROJECT = "project", "프로젝트"
        CONTEST = "contest", "대회"
        EVENT = "event", "행사"

    class Status(models.TextChoices):
        PLANNING = "planning", "준비 중"
        ONGOING = "ongoing", "진행 중"
        DONE = "done", "완료"
        # 학기가 끝난 기록. 참여자는 더 이상 자료를 올리거나 고칠 수 없고 운영진만 손댈 수 있다.
        ARCHIVED = "archived", "보관됨"

    kind = models.CharField("종류", max_length=10, choices=Kind.choices)
    semester = models.ForeignKey(Semester, on_delete=models.PROTECT, related_name="activities", verbose_name="학기")
    title = models.CharField("이름", max_length=150, help_text="프로젝트는 팀명, 대회·행사는 그 이름을 적습니다.")
    topic = models.CharField(
        "주제", max_length=200, blank=True, help_text="프로젝트 주제. 아직 정하지 않았으면 비워두면 '주제 선정 중'으로 보입니다."
    )
    summary = models.CharField("한 줄 소개", max_length=200, blank=True)
    description = models.TextField("소개", blank=True)
    status = models.CharField("상태", max_length=10, choices=Status.choices, default=Status.PLANNING)
    start_date = models.DateField("시작일", null=True, blank=True)
    end_date = models.DateField("종료일", null=True, blank=True)
    result = models.CharField("결과", max_length=150, blank=True, help_text="대회 순위·수상 등. 예: 본선 진출, 32위")
    team_name = models.CharField("참가 팀명", max_length=100, blank=True, help_text="대회에 나간 팀 이름")
    location = models.CharField("장소", max_length=150, blank=True, help_text="행사 장소")
    tags = models.ManyToManyField(Tag, blank=True, related_name="activities", verbose_name="분야 태그")
    is_published = models.BooleanField("사이트에 공개", default=True, help_text="끄면 사이트에 보이지 않습니다.")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.semester} · {self.title}"

    class Meta:
        ordering = ("-semester__name", "-start_date", "-id")
        verbose_name = "활동"
        verbose_name_plural = "활동"


class ActivityMember(models.Model):
    """활동 참여자. 계정이 지워져도 기록이 남도록 이름을 따로 저장한다."""

    class Role(models.TextChoices):
        LEADER = "leader", "팀장"
        MEMBER = "member", "참여자"

    activity = models.ForeignKey(Activity, on_delete=models.CASCADE, related_name="members")
    member = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="activity_memberships",
        verbose_name="회원",
        help_text="사이트 계정이 있으면 고릅니다. 연결된 회원만 사이트에서 자료를 올릴 수 있습니다.",
    )
    name = models.CharField("이름", max_length=50, blank=True, help_text="비워두면 회원 이름이 들어갑니다.")
    role = models.CharField("역할", max_length=10, choices=Role.choices, default=Role.MEMBER)

    def save(self, *args, **kwargs):
        if not self.name and self.member_id:
            self.name = self.member.name
        super().save(*args, **kwargs)

    def __str__(self):
        return self.name

    class Meta:
        ordering = ("role", "name", "id")  # 팀장(leader)이 참여자(member)보다 앞에 온다.
        verbose_name = "참여자"
        verbose_name_plural = "참여자"
        constraints = [
            models.UniqueConstraint(
                fields=("activity", "member"),
                condition=models.Q(member__isnull=False),
                name="unique_activity_member",
            ),
        ]


class Material(models.Model):
    """활동 자료 하나(제안서·중간 발표·최종 보고서·write-up·사진 등). 누구나 볼 수 있다."""

    class Stage(models.TextChoices):
        PROPOSAL = "proposal", "제안"
        INTERIM = "interim", "중간"
        FINAL = "final", "최종"
        OTHER = "other", "기타"

    activity = models.ForeignKey(Activity, on_delete=models.CASCADE, related_name="materials")
    stage = models.CharField("단계", max_length=10, choices=Stage.choices, default=Stage.OTHER)
    title = models.CharField("제목", max_length=200)
    description = models.TextField("설명", blank=True, help_text="GitHub·영상 링크도 여기에 적으면 눌러서 열 수 있습니다.")
    date = models.DateField("날짜", default=timezone.localdate)
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="+", verbose_name="올린 사람"
    )
    # 계정이 지워져도 누가 올렸는지 남긴다.
    author_name = models.CharField("올린 사람 이름", max_length=50, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def save(self, *args, **kwargs):
        if not self.author_name and self.author_id:
            self.author_name = self.author.name
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.activity} · {self.title}"

    class Meta:
        ordering = ("-date", "-id")
        verbose_name = "자료"
        verbose_name_plural = "자료"


def material_upload_to(instance, filename):
    """자료 저장 경로. 원본 파일명은 DB에만 두고 경로에는 추측하기 어려운 이름을 쓴다."""
    return f"activities/{instance.material.activity_id}/{instance.material_id}/{uuid.uuid4().hex}{safe_suffix(filename)}"


class MaterialFile(models.Model):
    """자료 첨부. 형식은 가리지 않고, 사진이 아니면 항상 내려받기로만 내보낸다."""

    material = models.ForeignKey(Material, on_delete=models.CASCADE, related_name="files")
    file = models.FileField("파일", upload_to=material_upload_to, max_length=255)
    original_name = models.CharField("원본 파일명", max_length=255, blank=True)
    content_type = models.CharField("종류", max_length=120, blank=True)
    size = models.PositiveBigIntegerField("크기(바이트)", default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    @property
    def is_image(self):
        return is_inline_image(self.original_name)

    def save(self, *args, **kwargs):
        # Admin에서 올릴 때도 원본 파일명·크기·종류가 채워지게 한다.
        if not self.original_name:
            self.original_name = Path(getattr(self.file, "name", "") or "").name[-255:]
        if not self.size:
            self.size = getattr(self.file, "size", 0) or 0
        if not self.content_type:
            self.content_type = content_type_of(self.original_name)[:120]
        super().save(*args, **kwargs)

    def __str__(self):
        return self.original_name

    class Meta:
        ordering = ("id",)
        verbose_name = "자료 첨부"
        verbose_name_plural = "자료 첨부"


@receiver(post_delete, sender=MaterialFile)
def _delete_material_file(sender, instance, **kwargs):
    """첨부 기록을 지우면(자료·활동을 통째로 지울 때 포함) 실제 파일도 지운다."""
    if instance.file:
        instance.file.delete(save=False)
