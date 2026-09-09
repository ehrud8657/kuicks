from django.core.management.base import BaseCommand
from django.db import transaction

from apps.accounts.models import Member
from apps.studies.models import Study, sync_leader_roles


class Command(BaseCommand):
    help = (
        "Study.leader 지정 상태를 기준으로 회원 등급을 일괄 정리합니다. "
        "등급 자동 동기화는 Study 저장 시점에 동작하므로, 그 이전에 등록된 스터디는 "
        "이 명령을 한 번 실행해 등급을 맞춰야 합니다."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="실제로 저장하지 않고 바뀔 내용만 보여줍니다.",
        )

    def handle(self, *args, **options):
        # 스터디장으로 지정된 회원 + 이미 스터디장 등급인 회원(담당이 사라진 경우를 잡기 위해)
        member_ids = set(Study.objects.exclude(leader=None).values_list("leader_id", flat=True))
        member_ids |= set(
            Member.objects.filter(role=Member.Role.LEADER).values_list("pk", flat=True)
        )
        if not member_ids:
            self.stdout.write("동기화할 대상이 없습니다.")
            return

        names = dict(Member.objects.filter(pk__in=member_ids).values_list("pk", "name"))
        before = dict(Member.objects.filter(pk__in=member_ids).values_list("pk", "role"))

        if options["dry_run"]:
            # 판정 로직을 그대로 재사용하기 위해 실제로 실행한 뒤 롤백한다.
            with transaction.atomic():
                sync_leader_roles(*member_ids)
                after = dict(
                    Member.objects.filter(pk__in=member_ids).values_list("pk", "role")
                )
                transaction.set_rollback(True)
        else:
            sync_leader_roles(*member_ids)
            after = dict(Member.objects.filter(pk__in=member_ids).values_list("pk", "role"))

        labels = dict(Member.Role.choices)
        changed = [
            (member_id, before[member_id], after[member_id])
            for member_id in sorted(member_ids)
            if before[member_id] != after[member_id]
        ]

        for member_id, old, new in changed:
            self.stdout.write(
                f"{names.get(member_id, '')} ({member_id}): {labels[old]} → {labels[new]}"
            )

        prefix = "[dry-run] " if options["dry_run"] else ""
        self.stdout.write(
            self.style.SUCCESS(
                f"{prefix}대상 {len(member_ids)}명 중 {len(changed)}명의 등급을 정리했습니다."
            )
        )
