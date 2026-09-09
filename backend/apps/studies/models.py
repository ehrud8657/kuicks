from django.conf import settings
from django.db import models
from django.db.models.signals import post_delete
from django.dispatch import receiver

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
