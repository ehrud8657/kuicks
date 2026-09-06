import csv
import sys

from django.core.management.base import BaseCommand, CommandError

from apps.accounts.models import Member

DELIMITERS = {"tab": "\t", "comma": ",", "semicolon": ";"}


class Command(BaseCommand):
    help = (
        "현재 DB의 회원 명단을 학번,이름,회원상태 형식으로 내보냅니다. "
        "내보낸 파일을 스프레드시트에서 편집한 뒤 import_members --update 로 되돌려 넣을 수 있습니다. "
        "비밀번호는 포함되지 않습니다."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "csv_file",
            nargs="?",
            help="저장할 파일 경로. 생략하면 화면에 출력합니다.",
        )
        parser.add_argument(
            "--delimiter",
            choices=sorted(DELIMITERS),
            default="tab",
            help="구분자 (기본: tab — 스프레드시트에 붙여넣기 좋은 형식)",
        )

    def handle(self, *args, **options):
        delimiter = DELIMITERS[options["delimiter"]]
        members = Member.objects.order_by("student_id").values_list("student_id", "name", "role")
        role_labels = dict(Member.Role.choices)

        path = options["csv_file"]
        try:
            stream = open(path, "w", encoding="utf-8-sig", newline="") if path else sys.stdout
        except OSError as exc:
            raise CommandError(str(exc)) from exc

        try:
            writer = csv.writer(stream, delimiter=delimiter, lineterminator="\n")
            writer.writerow(["학번", "이름", "회원상태"])
            count = 0
            for student_id, name, role in members:
                writer.writerow([student_id, name, role_labels.get(role, role)])
                count += 1
        finally:
            if path:
                stream.close()

        if path:
            self.stdout.write(self.style.SUCCESS(f"{count}명을 {path} 에 저장했습니다."))
