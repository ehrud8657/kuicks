import uuid

from django.conf import settings
from django.db import models
from django.db.models.signals import post_delete
from django.dispatch import receiver
from django.utils import timezone

class Semester(models.Model):
    name = models.CharField("학기", max_length=20, unique=True)
    starts_at = models.DateField("시작일", null=True, blank=True)
    def __str__(self): return self.name
    class Meta:
        ordering = ("-name",)

class Study(models.Model):
    semester = models.ForeignKey(Semester, on_delete=models.PROTECT, related_name="studies")
    title = models.CharField("스터디명", max_length=100)
    # 스터디장이 아직 정해지지 않은 스터디도 미리 등록할 수 있어야 해서 비워둘 수 있다.
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
    # 스터디 소개 화면에 보여줄 안내. 형식이 스터디마다 달라 여러 줄 자유 입력으로 둔다.
    method = models.TextField("진행 방식", blank=True, help_text="예: 대면 · 매주 발표와 실습")
    schedule = models.TextField("일정", blank=True, help_text="예: 매주 화요일 19:00, 3월 둘째 주 ~ 6월 첫째 주")
    completion_requirements = models.TextField("수료 요건", blank=True, help_text="예: 출석 80% 이상, 과제 제출")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    def __str__(self): return f"{self.semester} · {self.title}"

    def save(self, *args, **kwargs):
        # 스터디장이 교체되면 이전 담당자의 등급도 함께 정리해야 하므로 저장 전 값을 읽어둔다.
        previous_leader_id = (
            Study.objects.filter(pk=self.pk).values_list("leader_id", flat=True).first()
            if self.pk
            else None
        )
        super().save(*args, **kwargs)
        sync_leader_roles(previous_leader_id, self.leader_id)

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


class StudySession(models.Model):
    """스터디 회차. 출석은 회차 단위로 기록한다."""

    study = models.ForeignKey(Study, on_delete=models.CASCADE, related_name="sessions")
    number = models.PositiveIntegerField("회차")
    title = models.CharField("주제", max_length=100, blank=True)
    held_on = models.DateField("진행일")
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.study} · {self.number}회차"

    class Meta:
        ordering = ("number",)
        constraints = [models.UniqueConstraint(fields=("study", "number"), name="unique_session_number_per_study")]


class Attendance(models.Model):
    class Status(models.TextChoices):
        PRESENT = "present", "출석"
        LATE = "late", "지각"
        ABSENT = "absent", "결석"
        EXCUSED = "excused", "공결"

    session = models.ForeignKey(StudySession, on_delete=models.CASCADE, related_name="attendances")
    # 회원이 아니라 참여 기록에 연결해, 스터디 명단에 있는 사람만 출석을 가질 수 있게 한다.
    participation = models.ForeignKey(Participation, on_delete=models.CASCADE, related_name="attendances")
    status = models.CharField("출석 상태", max_length=10, choices=Status.choices)
    note = models.CharField("메모", max_length=200, blank=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.session} · {self.participation.member} · {self.get_status_display()}"

    class Meta:
        constraints = [models.UniqueConstraint(fields=("session", "participation"), name="unique_attendance_per_session")]


class Assignment(models.Model):
    study = models.ForeignKey(Study, on_delete=models.CASCADE, related_name="assignments")
    title = models.CharField("제목", max_length=150)
    description = models.TextField("설명", blank=True)
    due_at = models.DateTimeField("제출 기한")
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.study} · {self.title}"

    class Meta:
        ordering = ("due_at", "id")


def submission_upload_to(instance, filename):
    """제출 파일 저장 경로. 원본 파일명은 DB에만 두고, 경로에는 추측하기 어려운 이름을 쓴다."""
    assignment = instance.assignment
    member_id = instance.participation.member_id
    return f"submissions/{assignment.study_id}/{assignment.pk}/{member_id}_{uuid.uuid4().hex[:12]}.zip"


class AssignmentSubmission(models.Model):
    """과제 제출. 참여자당 과제 하나에 한 건이며, 다시 제출하면 파일을 교체한다."""

    class ReviewStatus(models.TextChoices):
        PENDING = "pending", "미확인"
        CHECKED = "checked", "확인"

    assignment = models.ForeignKey(Assignment, on_delete=models.CASCADE, related_name="submissions")
    participation = models.ForeignKey(Participation, on_delete=models.CASCADE, related_name="submissions")
    file = models.FileField("제출 파일", upload_to=submission_upload_to, max_length=255)
    original_name = models.CharField("원본 파일명", max_length=255)
    size = models.PositiveBigIntegerField("크기(바이트)")
    submitted_at = models.DateTimeField("제출 시각", default=timezone.now)
    review_status = models.CharField(
        "확인 여부", max_length=10, choices=ReviewStatus.choices, default=ReviewStatus.PENDING
    )
    feedback = models.TextField("피드백", blank=True)
    reviewed_at = models.DateTimeField("확인 시각", null=True, blank=True)
    reviewed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )

    @property
    def is_late(self):
        return self.submitted_at > self.assignment.due_at

    def __str__(self):
        return f"{self.assignment} · {self.participation.member}"

    class Meta:
        ordering = ("submitted_at",)
        constraints = [
            models.UniqueConstraint(fields=("assignment", "participation"), name="unique_submission_per_assignment")
        ]


def sync_leader_roles(*member_ids):
    """Study.leader 지정 상태를 회원 등급(role)에 반영한다.

    - 정회원/휴회원이 스터디장으로 지정되면 스터디장으로 승급한다.
    - 담당 스터디가 하나도 남지 않은 스터디장은 정회원으로 되돌린다.
    - 운영진은 스터디장보다 상위 권한이므로 등급을 건드리지 않는다.

    queryset.update()/bulk_create()처럼 save()를 거치지 않는 경로에서는 동작하지 않으니,
    일괄 변경 후에는 이 함수를 직접 호출해야 한다.
    """
    # accounts가 INSTALLED_APPS에서 먼저 로드되지만, 모듈 로딩 순서에 의존하지 않도록 함수 안에서 import한다.
    from apps.accounts.models import Member

    ids = {member_id for member_id in member_ids if member_id}
    if not ids:
        return

    for member in Member.objects.filter(pk__in=ids):
        leads_any = Study.objects.filter(leader_id=member.pk).exists()
        if leads_any and member.role in (Member.Role.MEMBER, Member.Role.DORMANT):
            member.role = Member.Role.LEADER
        elif not leads_any and member.role == Member.Role.LEADER:
            member.role = Member.Role.MEMBER
        else:
            # 운영진이거나 이미 등급이 맞는 경우
            continue
        member.save(update_fields=["role", "is_staff", "is_superuser"])


@receiver(post_delete, sender=Study)
def _sync_leader_role_on_study_delete(sender, instance, **kwargs):
    sync_leader_roles(instance.leader_id)


@receiver(post_delete, sender=AssignmentSubmission)
def _delete_submission_file(sender, instance, **kwargs):
    # 과제·스터디가 지워져 연쇄 삭제될 때도 저장소에 파일이 남지 않게 한다.
    if instance.file:
        instance.file.delete(save=False)
