from django.conf import settings
from django.db import models

class Semester(models.Model):
    name = models.CharField("학기", max_length=20, unique=True)
    starts_at = models.DateField("시작일", null=True, blank=True)
    def __str__(self): return self.name
    class Meta:
        ordering = ("-name",)

class Study(models.Model):
    semester = models.ForeignKey(Semester, on_delete=models.PROTECT, related_name="studies")
    title = models.CharField("스터디명", max_length=100)
    leader = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="led_studies",
        null=True,
        blank=True,
    )
    description = models.TextField("설명", blank=True)
    prerequisites = models.CharField("선이수과목", max_length=200, blank=True)
    recommended = models.CharField("권장과목", max_length=200, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    def __str__(self): return f"{self.semester} · {self.title}"
    class Meta:
        ordering = ("title",)
        constraints = [models.UniqueConstraint(fields=("semester", "title"), name="unique_study_per_semester")]

class Participation(models.Model):
    class Status(models.TextChoices):
        ACTIVE = "active", "수강 중"
        COMPLETED = "completed", "수료"
        EXCELLENT = "excellent", "우수 수료"
        WITHDRAWN = "withdrawn", "중도 포기"
    member = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="participations")
    study = models.ForeignKey(Study, on_delete=models.CASCADE, related_name="participations")
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.ACTIVE)
    updated_at = models.DateTimeField(auto_now=True)
    def __str__(self): return f"{self.member} · {self.study}"
    class Meta:
        constraints = [models.UniqueConstraint(fields=("member", "study"), name="unique_study_participation")]

class AssignmentSubmit(models.Model):
    class Status(models.TextChoices):
        SUBMITTED = "submitted", "제출"
        ACCEPTED = "accepted", "승인"
        REJECTED = "rejected", "반려"
    member = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="assignment_submits")
    study = models.ForeignKey(Study, on_delete=models.CASCADE, related_name="assignment_submits")
    file_url = models.URLField("파일 URL", max_length=500)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.SUBMITTED)
    created_at = models.DateTimeField(auto_now_add=True)
    def __str__(self): return f"{self.member} · {self.study} · {self.status}"

