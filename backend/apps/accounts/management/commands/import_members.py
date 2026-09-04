import csv
from django.core.management.base import BaseCommand, CommandError
from apps.accounts.models import Member

INITIAL_PASSWORD_PREFIX = "kuics!"


class Command(BaseCommand):
    help = (
        "학번,이름 열이 있는 UTF-8 CSV에서 회원을 일괄 생성합니다. "
        "초기 비밀번호는 'kuics!학번' 형식으로 고정 부여되며, "
        "이미 등록된 학번은 건너뛰므로 모집 중 새 명단이 추가될 때마다 재실행해도 안전합니다."
    )

    def add_arguments(self, parser):
        parser.add_argument("csv_file")

    def handle(self, *args, **options):
        created = skipped = 0
        try:
            with open(options["csv_file"], encoding="utf-8-sig", newline="") as file:
                for row in csv.DictReader(file):
                    student_id, name = row.get("학번", "").strip(), row.get("이름", "").strip()
                    if not student_id or not name:
                        skipped += 1
                        continue
                    if Member.objects.filter(student_id=student_id).exists():
                        skipped += 1
                        continue
                    password = f"{INITIAL_PASSWORD_PREFIX}{student_id}"
                    Member.objects.create_user(student_id=student_id, name=name, password=password)
                    self.stdout.write(f"CREATED {student_id} ({name})")
                    created += 1
        except OSError as exc:
            raise CommandError(str(exc)) from exc
        self.stdout.write(self.style.SUCCESS(f"생성 {created}명, 건너뜀 {skipped}명"))
