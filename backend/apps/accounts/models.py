from django.contrib.auth.base_user import BaseUserManager
from django.contrib.auth.models import AbstractUser
from django.db import models


class MemberManager(BaseUserManager):
    use_in_migrations = True

    def create_user(self, student_id, password=None, **extra_fields):
        if not student_id:
            raise ValueError("학번은 필수입니다.")
        user = self.model(student_id=str(student_id), **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, student_id, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("role", Member.Role.ADMIN)
        return self.create_user(student_id, password, **extra_fields)


class Member(AbstractUser):
    class Role(models.TextChoices):
        MEMBER = "member", "일반 회원"
        LEADER = "leader", "스터디장"
        ADMIN = "admin", "운영진"

    username = None
    student_id = models.CharField("학번", max_length=20, primary_key=True)
    name = models.CharField("이름", max_length=50)
    role = models.CharField("권한", max_length=10, choices=Role.choices, default=Role.MEMBER)
    must_change_password = models.BooleanField("비밀번호 변경 필요", default=True)

    USERNAME_FIELD = "student_id"
    REQUIRED_FIELDS = ["name"]
    objects = MemberManager()

    def __str__(self):
        return f"{self.name} ({self.student_id})"

