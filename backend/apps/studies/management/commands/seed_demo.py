import zipfile
from datetime import timedelta
from io import BytesIO

from django.conf import settings
from django.core.files.base import ContentFile
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.utils import timezone

from apps.accounts.models import Member
from apps.studies.models import (
    Assignment,
    AssignmentSubmission,
    Attendance,
    Participation,
    Semester,
    Study,
    StudySession,
)

DEMO_PASSWORD = "Kuics-demo-2026!"
SEMESTER_NAME = "2099-1"


class Command(BaseCommand):
    help = (
        "로컬 개발용 가상 데이터(학기·스터디장·참여자·회차·출석·과제·제출)를 만듭니다. "
        "학번은 실제 회원과 겹치지 않게 2099로 시작하며, 여러 번 실행해도 중복 생성하지 않습니다. "
        "DEBUG=false(운영) 환경에서는 실행을 거부합니다."
    )

    def handle(self, *args, **options):
        if not settings.DEBUG:
            raise CommandError("운영 환경(DJANGO_DEBUG=false)에서는 가상 데이터를 만들 수 없습니다.")

        with transaction.atomic():
            leader = self._member("2099000001", "김스터디장")
            other_leader = self._member("2099000002", "박다른장")
            self._member("2099000009", "최운영", role=Member.Role.ADMIN)
            participants = [
                self._member("2099000101", "홍길동"),
                self._member("2099000102", "이영희"),
                self._member("2099000103", "박철수"),
                self._member("2099000104", "정민지"),
            ]

            semester, _ = Semester.objects.get_or_create(name=SEMESTER_NAME)
            study, created = Study.objects.get_or_create(
                semester=semester,
                title="[예시] 웹해킹 입문",
                defaults={
                    "leader": leader,
                    "description": "OWASP Top 10을 실습 위주로 다룹니다.",
                    "prerequisites": "없음",
                    "recommended": "웹 기초",
                },
            )
            Study.objects.get_or_create(
                semester=semester, title="[예시] 디지털 포렌식", defaults={"leader": other_leader}
            )
            if not created:
                self.stdout.write("이미 가상 데이터가 있어 회원 정보만 확인했습니다.")
                self._print_accounts()
                return

            roster = [Participation.objects.create(member=member, study=study) for member in participants]
            roster[-1].status = Participation.Status.WITHDRAWN
            roster[-1].save()

            today = timezone.localdate()
            for number, (title, days_ago) in enumerate([("OT", 14), ("SQL Injection", 7), ("XSS", 0)], start=1):
                session = StudySession.objects.create(
                    study=study, number=number, title=title, held_on=today - timedelta(days=days_ago)
                )
                if days_ago == 0:
                    continue  # 오늘 회차는 아직 출석을 기록하지 않은 상태로 둔다.
                statuses = ["present", "late" if number == 2 else "present", "absent", "excused"]
                for participation, status in zip(roster, statuses):
                    Attendance.objects.create(session=session, participation=participation, status=status)

            now = timezone.now()
            past = Assignment.objects.create(
                study=study,
                title="SQL Injection 실습 보고서",
                description="DVWA Low/Medium 풀이 과정을 정리해 zip으로 제출하세요.",
                due_at=now - timedelta(days=1),
                created_by=leader,
            )
            Assignment.objects.create(
                study=study,
                title="XSS 필터 우회",
                description="과제 파일과 풀이 문서를 함께 압축해 제출하세요.",
                due_at=now + timedelta(days=6),
                created_by=leader,
            )
            self._submit(past, roster[0], "홍길동_SQLi.zip", now - timedelta(days=2))
            self._submit(past, roster[1], "이영희_보고서.zip", now - timedelta(hours=3))

        self.stdout.write(self.style.SUCCESS("가상 데이터를 만들었습니다."))
        self._print_accounts()

    def _member(self, student_id, name, role=Member.Role.MEMBER):
        member = Member.objects.filter(pk=student_id).first()
        if member is None:
            member = Member.objects.create_user(
                student_id=student_id, name=name, password=DEMO_PASSWORD, role=role, must_change_password=False
            )
        return member

    def _submit(self, assignment, participation, name, submitted_at):
        buffer = BytesIO()
        with zipfile.ZipFile(buffer, "w") as archive:
            archive.writestr("README.txt", f"{participation.member.name}의 예시 제출물입니다.")
        data = buffer.getvalue()
        submission = AssignmentSubmission(
            assignment=assignment,
            participation=participation,
            original_name=name,
            size=len(data),
            submitted_at=submitted_at,
        )
        submission.file.save(name, ContentFile(data), save=False)
        submission.save()

    def _print_accounts(self):
        self.stdout.write(
            f"비밀번호는 모두 {DEMO_PASSWORD}\n"
            "  스터디장  2099000001 김스터디장 ([예시] 웹해킹 입문)\n"
            "  스터디장  2099000002 박다른장 ([예시] 디지털 포렌식)\n"
            "  운영진    2099000009 최운영\n"
            "  참여자    2099000101 홍길동 / 2099000102 이영희 / 2099000103 박철수 / 2099000104 정민지(중도 포기)"
        )
