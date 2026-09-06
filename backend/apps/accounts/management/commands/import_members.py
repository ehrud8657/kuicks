import csv
from django.core.management.base import BaseCommand, CommandError
from apps.accounts.models import Member

INITIAL_PASSWORD_PREFIX = "kuics!"


# Role의 label(휴회원/정회원/스터디장/운영진) -> value 매핑을 모델에서 그대로 가져와 항상 동기화되게 한다.
ROLE_LABEL_TO_VALUE = {label: value for value, label in Member.Role.choices}


class Command(BaseCommand):
    help = (
        "학번,이름,회원상태 열이 있는 UTF-8 CSV(또는 구글시트에서 그대로 복사한 탭/세미콜론 구분 텍스트)에서 "
        "회원을 일괄 생성합니다. 구분자는 자동으로 판별합니다. "
        "회원상태는 '정회원'/'휴회원'/'스터디장'/'운영진' 중 하나이며 비워두면 정회원으로 생성됩니다. "
        "초기 비밀번호는 'kuics!학번' 형식으로 고정 부여되며, "
        "이미 등록된 학번은 건너뛰므로 모집 중 새 명단이 추가될 때마다 재실행해도 안전합니다."
    )

    def add_arguments(self, parser):
        parser.add_argument("csv_file")

    def handle(self, *args, **options):
        created = skipped = 0
        try:
            with open(options["csv_file"], encoding="utf-8-sig", newline="") as file:
                sample = file.read(4096)
                file.seek(0)
                try:
                    dialect = csv.Sniffer().sniff(sample, delimiters=",\t;")
                except csv.Error:
                    dialect = csv.excel  # 구분자 판별 실패 시 콤마로 취급
                for row in csv.DictReader(file, dialect=dialect):
                    student_id, name = row.get("학번", "").strip(), row.get("이름", "").strip()
                    status_label = row.get("회원상태", "").strip()
                    if not student_id or not name:
                        skipped += 1
                        continue
                    if Member.objects.filter(student_id=student_id).exists():
                        skipped += 1
                        continue
                    if status_label:
                        role = ROLE_LABEL_TO_VALUE.get(status_label)
                        if role is None:
                            self.stderr.write(self.style.WARNING(
                                f"SKIPPED {student_id} ({name}) - 알 수 없는 회원상태 '{status_label}' "
                                f"(가능한 값: {', '.join(ROLE_LABEL_TO_VALUE)})"
                            ))
                            skipped += 1
                            continue
                    else:
                        role = Member.Role.MEMBER
                    password = f"{INITIAL_PASSWORD_PREFIX}{student_id}"
                    Member.objects.create_user(student_id=student_id, name=name, password=password, role=role)
                    self.stdout.write(f"CREATED {student_id} ({name}, {status_label or '정회원'})")
                    created += 1
        except OSError as exc:
            raise CommandError(str(exc)) from exc
        self.stdout.write(self.style.SUCCESS(f"생성 {created}명, 건너뜀 {skipped}명"))
