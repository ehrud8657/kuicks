from io import StringIO

from django.core.management import call_command
from django.test import TestCase
from django.urls import reverse

from apps.accounts.models import Member
from .models import Participation, Semester, Study


def create_member(student_id, name, role=Member.Role.MEMBER):
    return Member.objects.create_user(student_id=student_id, password="kuics!test", name=name, role=role)


class StudyLeaderTests(TestCase):
    def setUp(self):
        self.semester = Semester.objects.create(name="2026-1")

    def test_스터디장_없이_스터디를_만들_수_있다(self):
        study = Study.objects.create(semester=self.semester, title="리버싱 입문")
        self.assertIsNone(study.leader)

    def test_정회원을_스터디장으로_지정하면_등급이_올라간다(self):
        member = create_member("2026320001", "김정회")
        Study.objects.create(semester=self.semester, title="웹해킹", leader=member)
        member.refresh_from_db()
        self.assertEqual(member.role, Member.Role.LEADER)

    def test_휴회원을_스터디장으로_지정해도_등급이_올라간다(self):
        member = create_member("2026320002", "이휴회", role=Member.Role.DORMANT)
        Study.objects.create(semester=self.semester, title="포렌식", leader=member)
        member.refresh_from_db()
        self.assertEqual(member.role, Member.Role.LEADER)

    def test_운영진은_스터디장으로_지정해도_등급이_유지된다(self):
        admin = create_member("2026320003", "박운영", role=Member.Role.ADMIN)
        Study.objects.create(semester=self.semester, title="시스템해킹", leader=admin)
        admin.refresh_from_db()
        self.assertEqual(admin.role, Member.Role.ADMIN)
        self.assertTrue(admin.is_staff)

    def test_스터디장을_미정으로_되돌리면_정회원으로_내려간다(self):
        member = create_member("2026320004", "최담당")
        study = Study.objects.create(semester=self.semester, title="암호학", leader=member)
        study.leader = None
        study.save()
        member.refresh_from_db()
        self.assertEqual(member.role, Member.Role.MEMBER)

    def test_스터디장_교체시_이전_담당자만_내려간다(self):
        before = create_member("2026320005", "이전장")
        after = create_member("2026320006", "새담당")
        study = Study.objects.create(semester=self.semester, title="네트워크", leader=before)
        study.leader = after
        study.save()
        before.refresh_from_db()
        after.refresh_from_db()
        self.assertEqual(before.role, Member.Role.MEMBER)
        self.assertEqual(after.role, Member.Role.LEADER)

    def test_담당_스터디가_남아있으면_등급을_유지한다(self):
        member = create_member("2026320007", "두개장")
        first = Study.objects.create(semester=self.semester, title="스터디A", leader=member)
        Study.objects.create(semester=self.semester, title="스터디B", leader=member)
        first.leader = None
        first.save()
        member.refresh_from_db()
        self.assertEqual(member.role, Member.Role.LEADER)

    def test_스터디를_삭제하면_등급이_정리된다(self):
        member = create_member("2026320008", "삭제장")
        study = Study.objects.create(semester=self.semester, title="스터디C", leader=member)
        study.delete()
        member.refresh_from_db()
        self.assertEqual(member.role, Member.Role.MEMBER)


class SemesterApiTests(TestCase):
    def setUp(self):
        self.semester = Semester.objects.create(name="2026-1")
        self.leader = create_member("2026320011", "강스터")
        self.study = Study.objects.create(semester=self.semester, title="웹해킹", leader=self.leader)
        self.member = create_member("2026320044", "홍길동")
        Participation.objects.create(
            member=self.member, study=self.study, status=Participation.Status.COMPLETED
        )

    def _study_payload(self):
        response = self.client.get(reverse("semester-list"))
        self.assertEqual(response.status_code, 200)
        return response.json()[0]["studies"][0]

    def test_수료자는_이름과_학번_뒷_2자리로_내려온다(self):
        participation = self._study_payload()["participations"][0]
        self.assertEqual(participation["member_name"], "홍길동")
        self.assertEqual(participation["student_id_tail"], "44")

    def test_공개_응답에_학번_전체가_포함되지_않는다(self):
        response = self.client.get(reverse("semester-list"))
        self.assertNotIn("2026320044", response.content.decode())
        self.assertNotIn("2026320011", response.content.decode())

    def test_스터디장이_없으면_미정으로_내려온다(self):
        self.study.leader = None
        self.study.save()
        self.assertEqual(self._study_payload()["leader_name"], "미정")


class MyStudyApiTests(TestCase):
    """마이페이지의 수강 중/수료 스터디 카드가 쓰는 엔드포인트."""

    def setUp(self):
        self.semester = Semester.objects.create(name="2026-1")
        self.member = create_member("2026320031", "내학생")
        self.other = create_member("2026320032", "남학생")
        self.active = Study.objects.create(semester=self.semester, title="수강중스터디")
        self.done = Study.objects.create(semester=self.semester, title="수료스터디")
        Participation.objects.create(
            member=self.member, study=self.active, status=Participation.Status.ACTIVE
        )
        Participation.objects.create(
            member=self.member, study=self.done, status=Participation.Status.EXCELLENT
        )
        Participation.objects.create(
            member=self.other, study=self.active, status=Participation.Status.ACTIVE
        )

    def test_로그인하지_않으면_조회할_수_없다(self):
        response = self.client.get(reverse("my-study-list"))
        self.assertIn(response.status_code, (401, 403))

    def test_본인_참여_이력만_내려온다(self):
        self.client.force_login(self.member)
        response = self.client.get(reverse("my-study-list"))
        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(len(payload), 2)
        by_title = {item["title"]: item for item in payload}
        self.assertEqual(by_title["수강중스터디"]["status"], "active")
        self.assertEqual(by_title["수료스터디"]["status"], "excellent")
        self.assertEqual(by_title["수료스터디"]["status_label"], "우수 수료")
        self.assertEqual(by_title["수료스터디"]["semester"], "2026-1")

    def test_다른_회원의_참여는_보이지_않는다(self):
        self.client.force_login(self.other)
        response = self.client.get(reverse("my-study-list"))
        payload = response.json()
        self.assertEqual([item["title"] for item in payload], ["수강중스터디"])


class SyncLeaderRolesCommandTests(TestCase):
    """등급 동기화가 없던 시절에 등록된 데이터를 정리하는 일회성 명령."""

    def setUp(self):
        self.semester = Semester.objects.create(name="2026-1")
        self.member = create_member("2026320021", "옛날장")
        Study.objects.create(semester=self.semester, title="스터디D", leader=self.member)
        # Study.save()가 올려둔 등급을 되돌려, 동기화 이전 데이터 상태를 만든다.
        Member.objects.filter(pk=self.member.pk).update(role=Member.Role.MEMBER)

    def test_등급이_어긋난_스터디장을_정리한다(self):
        out = StringIO()
        call_command("sync_leader_roles", stdout=out)
        self.member.refresh_from_db()
        self.assertEqual(self.member.role, Member.Role.LEADER)
        self.assertIn("1명의 등급을 정리했습니다", out.getvalue())

    def test_dry_run은_저장하지_않는다(self):
        out = StringIO()
        call_command("sync_leader_roles", "--dry-run", stdout=out)
        self.member.refresh_from_db()
        self.assertEqual(self.member.role, Member.Role.MEMBER)
        self.assertIn("dry-run", out.getvalue())
        self.assertIn("1명의 등급을 정리했습니다", out.getvalue())
