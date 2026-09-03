import csv
import secrets
import string
from django.core.management.base import BaseCommand, CommandError
from apps.accounts.models import Member

class Command(BaseCommand):
    help = "학번,이름 열이 있는 UTF-8 CSV에서 회원을 일괄 생성합니다."

    def add_arguments(self, parser):
        parser.add_argument("csv_file")

    def handle(self, *args, **options):
        created = skipped = 0
        alphabet = string.ascii_letters + string.digits
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
                    password = "".join(secrets.choice(alphabet) for _ in range(12))
                    Member.objects.create_user(student_id=student_id, name=name, password=password)
                    self.stdout.write(f"CREATED {student_id} temporary_password={password}")
                    created += 1
        except OSError as exc:
            raise CommandError(str(exc)) from exc
        self.stdout.write(self.style.SUCCESS(f"생성 {created}명, 건너뜀 {skipped}명"))
