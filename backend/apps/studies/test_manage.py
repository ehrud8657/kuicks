import shutil
import tempfile
import zipfile
from datetime import timedelta
from io import BytesIO
from pathlib import Path

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from django.urls import reverse
from django.utils import timezone

from apps.accounts.models import Member
from .models import Assignment, AssignmentSubmission, Attendance, Participation, Semester, Study, StudySession

TEMP_MEDIA = tempfile.mkdtemp(prefix="kuics-test-media-")


def create_member(student_id, name, role=Member.Role.MEMBER):
    return Member.objects.create_user(
        student_id=student_id, password="kuics!test", name=name, role=role, must_change_password=False
    )


def make_zip(content=b"print('hello')"):
    buffer = BytesIO()
    with zipfile.ZipFile(buffer, "w") as archive:
        archive.writestr("main.py", content)
    return buffer.getvalue()


def zip_upload(name="1주차 과제.zip", data=None):
    return SimpleUploadedFile(name, make_zip() if data is None else data, content_type="application/zip")


@override_settings(MEDIA_ROOT=TEMP_MEDIA)
class StudyManageTestBase(TestCase):
    """스터디장 A(웹해킹), 스터디장 B(포렌식), 운영진, 웹해킹 참여자 2명, 외부 회원."""

    @classmethod
    def setUpTestData(cls):
        cls.semester = Semester.objects.create(name="2026-2")
        cls.leader = create_member("2026100001", "김스터디장")
        cls.other_leader = create_member("2026100002", "박다른장")
        cls.admin = create_member("2026100003", "최운영", role=Member.Role.ADMIN)
        cls.member = create_member("2026100004", "홍참여")
        cls.member2 = create_member("2026100005", "이참여")
        cls.outsider = create_member("2026100006", "정외부")
        cls.study = Study.objects.create(semester=cls.semester, title="웹해킹", leader=cls.leader)
        cls.other_study = Study.objects.create(semester=cls.semester, title="포렌식", leader=cls.other_leader)
        cls.p1 = Participation.objects.create(member=cls.member, study=cls.study)
        cls.p2 = Participation.objects.create(member=cls.member2, study=cls.study)

    @classmethod
    def tearDownClass(cls):
        super().tearDownClass()
        shutil.rmtree(TEMP_MEDIA, ignore_errors=True)

    def send(self, method, url, data=None):
        return getattr(self.client, method)(url, data or {}, content_type="application/json")

    def create_session(self, study=None, **data):
        study = study or self.study
        return StudySession.objects.create(
            study=study, number=data.get("number", 1), title=data.get("title", ""), held_on=timezone.localdate()
        )

    def create_assignment(self, study=None, due_in=timedelta(days=7)):
        return Assignment.objects.create(study=study or self.study, title="XSS 실습", due_at=timezone.now() + due_in)


class ManageStudyAccessTests(StudyManageTestBase):
    def test_비로그인은_관리_API에_접근할_수_없다(self):
        response = self.client.get(reverse("manage-study-list"))
        self.assertEqual(response.status_code, 403)
        self.assertEqual(response.json()["code"], "not_authenticated")

    def test_일반_회원은_관리_API에_접근할_수_없다(self):
        self.client.force_login(self.member)
        response = self.client.get(reverse("manage-study-list"))
        self.assertEqual(response.status_code, 403)
        self.assertEqual(response.json()["code"], "permission_denied")

    def test_스터디장은_담당_스터디만_목록에_본다(self):
        self.client.force_login(self.leader)
        titles = [item["title"] for item in self.client.get(reverse("manage-study-list")).json()]
        self.assertEqual(titles, ["웹해킹"])

    def test_운영진은_모든_스터디를_본다(self):
        self.client.force_login(self.admin)
        titles = sorted(item["title"] for item in self.client.get(reverse("manage-study-list")).json())
        self.assertEqual(titles, ["웹해킹", "포렌식"])

    def test_등급만_스터디장이고_담당_스터디가_없으면_접근할_수_없다(self):
        fake_leader = create_member("2026100009", "등급만장")
        Member.objects.filter(pk=fake_leader.pk).update(role=Member.Role.LEADER)
        self.client.force_login(fake_leader)
        self.assertEqual(self.client.get(reverse("manage-study-list")).status_code, 403)

    def test_목록의_참여자_수에서_중도_포기자는_뺀다(self):
        Participation.objects.create(member=self.outsider, study=self.study, status=Participation.Status.WITHDRAWN)
        self.client.force_login(self.leader)
        item = self.client.get(reverse("manage-study-list")).json()[0]
        self.assertEqual(item["participant_count"], 2)

    def test_스터디장은_담당_스터디_상세에서_참여자_학번을_본다(self):
        self.client.force_login(self.leader)
        response = self.client.get(reverse("manage-study-detail", args=[self.study.pk]))
        self.assertEqual(response.status_code, 200)
        student_ids = [row["student_id"] for row in response.json()["participants"]]
        self.assertEqual(sorted(student_ids), ["2026100004", "2026100005"])

    def test_다른_스터디장의_스터디는_볼_수_없다(self):
        self.client.force_login(self.leader)
        response = self.client.get(reverse("manage-study-detail", args=[self.other_study.pk]))
        self.assertEqual(response.status_code, 403)
        self.assertEqual(response.json()["message"], "담당하는 스터디만 관리할 수 있습니다.")

    def test_운영진은_어느_스터디든_볼_수_있다(self):
        self.client.force_login(self.admin)
        self.assertEqual(self.client.get(reverse("manage-study-detail", args=[self.other_study.pk])).status_code, 200)

    def test_참여_상태_변경은_URL의_스터디와_맞아야_한다(self):
        self.client.force_login(self.admin)
        wrong = reverse("participation-update", args=[self.other_study.pk, self.p1.pk])
        self.assertEqual(self.send("patch", wrong, {"status": "completed"}).status_code, 404)
        right = reverse("participation-update", args=[self.study.pk, self.p1.pk])
        self.assertEqual(self.send("patch", right, {"status": "completed"}).status_code, 200)


class SessionAttendanceTests(StudyManageTestBase):
    def test_회차_번호를_비우면_다음_번호가_붙는다(self):
        self.client.force_login(self.leader)
        url = reverse("manage-session-create", args=[self.study.pk])
        first = self.send("post", url, {"title": "OT", "held_on": "2026-09-01"})
        second = self.send("post", url, {"title": "SQL Injection", "held_on": "2026-09-08"})
        self.assertEqual(first.status_code, 201)
        self.assertEqual((first.json()["number"], second.json()["number"]), (1, 2))

    def test_같은_회차_번호는_만들_수_없다(self):
        self.create_session(number=1)
        self.client.force_login(self.leader)
        response = self.send(
            "post", reverse("manage-session-create", args=[self.study.pk]), {"number": 1, "held_on": "2026-09-01"}
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("number", response.json()["fields"])

    def test_다른_스터디장은_회차를_만들거나_지울_수_없다(self):
        session = self.create_session()
        self.client.force_login(self.other_leader)
        create = self.send("post", reverse("manage-session-create", args=[self.study.pk]), {"held_on": "2026-09-01"})
        delete = self.client.delete(reverse("manage-session-detail", args=[session.pk]))
        self.assertEqual((create.status_code, delete.status_code), (403, 403))
        self.assertTrue(StudySession.objects.filter(pk=session.pk).exists())

    def test_출석을_한꺼번에_저장하고_다시_불러온다(self):
        session = self.create_session()
        self.client.force_login(self.leader)
        url = reverse("manage-session-attendance", args=[session.pk])
        response = self.send(
            "put",
            url,
            {
                "records": [
                    {"participation_id": self.p1.pk, "status": "present"},
                    {"participation_id": self.p2.pk, "status": "late", "note": "10분 지각"},
                ]
            },
        )
        self.assertEqual(response.status_code, 200)
        rows = {row["participation_id"]: row for row in self.client.get(url).json()["records"]}
        self.assertEqual(rows[self.p1.pk]["status"], "present")
        self.assertEqual((rows[self.p2.pk]["status"], rows[self.p2.pk]["note"]), ("late", "10분 지각"))

    def test_출석을_수정하고_지울_수_있다(self):
        session = self.create_session()
        Attendance.objects.create(session=session, participation=self.p1, status="absent")
        Attendance.objects.create(session=session, participation=self.p2, status="absent")
        self.client.force_login(self.leader)
        self.send(
            "put",
            reverse("manage-session-attendance", args=[session.pk]),
            {
                "records": [
                    {"participation_id": self.p1.pk, "status": "excused"},
                    {"participation_id": self.p2.pk, "status": None},
                ]
            },
        )
        self.assertEqual(Attendance.objects.get(participation=self.p1).status, "excused")
        self.assertFalse(Attendance.objects.filter(participation=self.p2).exists())

    def test_다른_스터디_참여자의_출석은_저장하지_않는다(self):
        session = self.create_session()
        outsider_participation = Participation.objects.create(member=self.outsider, study=self.other_study)
        self.client.force_login(self.leader)
        response = self.send(
            "put",
            reverse("manage-session-attendance", args=[session.pk]),
            {
                "records": [
                    {"participation_id": self.p1.pk, "status": "present"},
                    {"participation_id": outsider_participation.pk, "status": "present"},
                ]
            },
        )
        self.assertEqual(response.status_code, 400)
        self.assertFalse(Attendance.objects.exists())

    def test_참여자는_출석을_수정할_수_없다(self):
        session = self.create_session()
        self.client.force_login(self.member)
        response = self.send(
            "put",
            reverse("manage-session-attendance", args=[session.pk]),
            {"records": [{"participation_id": self.p1.pk, "status": "present"}]},
        )
        self.assertEqual(response.status_code, 403)

    def test_중도_포기자는_기록이_없으면_출석부에서_빠진다(self):
        session = self.create_session()
        Participation.objects.filter(pk=self.p2.pk).update(status=Participation.Status.WITHDRAWN)
        self.client.force_login(self.leader)
        rows = self.client.get(reverse("manage-session-attendance", args=[session.pk])).json()["records"]
        self.assertEqual([row["participation_id"] for row in rows], [self.p1.pk])

    def test_스터디_상세에_참여자별_출석_요약이_들어간다(self):
        first = self.create_session(number=1)
        second = self.create_session(number=2)
        Attendance.objects.create(session=first, participation=self.p1, status="present")
        Attendance.objects.create(session=second, participation=self.p1, status="late")
        self.client.force_login(self.leader)
        participants = self.client.get(reverse("manage-study-detail", args=[self.study.pk])).json()["participants"]
        summary = next(row for row in participants if row["id"] == self.p1.pk)["attendance"]
        self.assertEqual(summary, {"present": 1, "late": 1, "absent": 0, "excused": 0})


class AssignmentManageTests(StudyManageTestBase):
    def test_과제를_등록한다(self):
        self.client.force_login(self.leader)
        due = (timezone.now() + timedelta(days=3)).isoformat()
        response = self.send(
            "post",
            reverse("manage-assignment-create", args=[self.study.pk]),
            {"title": "  SQL Injection 실습  ", "description": "DVWA 풀이", "due_at": due},
        )
        self.assertEqual(response.status_code, 201)
        body = response.json()
        self.assertEqual((body["title"], body["submitted_count"]), ("SQL Injection 실습", 0))
        self.assertEqual(Assignment.objects.get().created_by, self.leader)

    def test_기한이_없거나_제목이_비면_거절한다(self):
        self.client.force_login(self.leader)
        response = self.send(
            "post", reverse("manage-assignment-create", args=[self.study.pk]), {"title": "   ", "description": ""}
        )
        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json()["code"], "invalid")
        self.assertEqual(set(response.json()["fields"]), {"title", "due_at"})

    def test_다른_스터디장은_과제를_수정할_수_없다(self):
        assignment = self.create_assignment()
        self.client.force_login(self.other_leader)
        response = self.send("patch", reverse("manage-assignment-detail", args=[assignment.pk]), {"title": "변경"})
        self.assertEqual(response.status_code, 403)

    def test_과제를_지우면_제출_파일도_지워진다(self):
        assignment = self.create_assignment()
        self.client.force_login(self.member)
        self.client.post(reverse("assignment-submit", args=[assignment.pk]), {"file": zip_upload()})
        path = Path(AssignmentSubmission.objects.get().file.path)
        self.assertTrue(path.exists())
        self.client.force_login(self.leader)
        self.assertEqual(self.client.delete(reverse("manage-assignment-detail", args=[assignment.pk])).status_code, 204)
        self.assertFalse(path.exists())


class SubmissionTests(StudyManageTestBase):
    def submit(self, assignment, member=None, upload=None):
        self.client.force_login(member or self.member)
        return self.client.post(reverse("assignment-submit", args=[assignment.pk]), {"file": upload or zip_upload()})

    def test_수강_중인_참여자가_zip을_제출한다(self):
        assignment = self.create_assignment()
        response = self.submit(assignment)
        self.assertEqual(response.status_code, 201)
        body = response.json()
        self.assertEqual((body["original_name"], body["is_late"], body["review_status"]), ("1주차 과제.zip", False, "pending"))
        self.assertTrue(Path(AssignmentSubmission.objects.get().file.path).exists())

    def test_기한이_지난_뒤_제출하면_지각으로_표시된다(self):
        assignment = self.create_assignment(due_in=timedelta(hours=-1))
        self.assertTrue(self.submit(assignment).json()["is_late"])

    def test_다시_제출하면_파일을_교체하고_확인_상태를_초기화한다(self):
        assignment = self.create_assignment()
        first_id = self.submit(assignment).json()["id"]
        submission = AssignmentSubmission.objects.get()
        old_path = Path(submission.file.path)
        submission.review_status = AssignmentSubmission.ReviewStatus.CHECKED
        submission.feedback = "좋아요"
        submission.save()

        response = self.submit(assignment, upload=zip_upload("수정본.zip"))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["id"], first_id)
        submission.refresh_from_db()
        self.assertEqual((submission.original_name, submission.review_status), ("수정본.zip", "pending"))
        self.assertEqual(submission.feedback, "좋아요")
        self.assertFalse(old_path.exists())
        self.assertTrue(Path(submission.file.path).exists())

    def test_zip이_아닌_파일은_거절한다(self):
        assignment = self.create_assignment()
        by_extension = self.submit(assignment, upload=SimpleUploadedFile("report.pdf", b"%PDF-1.4"))
        by_content = self.submit(assignment, upload=SimpleUploadedFile("fake.zip", b"not a zip at all"))
        self.assertEqual((by_extension.status_code, by_content.status_code), (400, 400))
        self.assertEqual(by_extension.json()["message"], "zip 파일만 제출할 수 있습니다.")
        self.assertFalse(AssignmentSubmission.objects.exists())

    def test_파일을_첨부하지_않으면_거절한다(self):
        assignment = self.create_assignment()
        self.client.force_login(self.member)
        response = self.client.post(reverse("assignment-submit", args=[assignment.pk]), {})
        self.assertEqual(response.status_code, 400)
        self.assertIn("file", response.json()["fields"])

    @override_settings(SUBMISSION_MAX_BYTES=64)
    def test_용량을_넘으면_거절한다(self):
        response = self.submit(self.create_assignment(), upload=zip_upload(data=make_zip(b"x" * 4096)))
        self.assertEqual(response.status_code, 400)
        self.assertIn("이하여야 합니다", response.json()["message"])

    def test_참여자가_아니거나_수강_중이_아니면_제출할_수_없다(self):
        assignment = self.create_assignment()
        Participation.objects.filter(pk=self.p2.pk).update(status=Participation.Status.COMPLETED)
        self.assertEqual(self.submit(assignment, member=self.outsider).status_code, 403)
        self.assertEqual(self.submit(assignment, member=self.member2).status_code, 403)

    def test_제출_현황에_미제출자와_지각_제출이_보인다(self):
        assignment = self.create_assignment(due_in=timedelta(hours=-1))
        self.submit(assignment)
        self.client.force_login(self.leader)
        body = self.client.get(reverse("manage-assignment-submissions", args=[assignment.pk])).json()
        rows = {row["participation_id"]: row for row in body["rows"]}
        self.assertTrue(rows[self.p1.pk]["submission"]["is_late"])
        self.assertIsNone(rows[self.p2.pk]["submission"])
        self.assertEqual((body["assignment"]["submitted_count"], body["assignment"]["late_count"]), (1, 1))

    def test_스터디장이_확인하고_피드백을_남긴다(self):
        assignment = self.create_assignment()
        submission_id = self.submit(assignment).json()["id"]
        self.client.force_login(self.leader)
        response = self.send(
            "patch",
            reverse("manage-submission-review", args=[submission_id]),
            {"review_status": "checked", "feedback": "필터 우회 부분이 좋습니다."},
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["reviewed_by_name"], "김스터디장")

        # 참여자는 본인 스터디 상세에서 확인 결과와 피드백을 본다.
        self.client.force_login(self.member)
        detail = self.client.get(reverse("my-study-detail", args=[self.study.pk])).json()
        submission = detail["assignments"][0]["submission"]
        self.assertEqual((submission["review_status"], submission["feedback"]), ("checked", "필터 우회 부분이 좋습니다."))

    def test_참여자나_다른_스터디장은_제출물을_확인_처리할_수_없다(self):
        submission_id = self.submit(self.create_assignment()).json()["id"]
        url = reverse("manage-submission-review", args=[submission_id])
        for member in (self.member, self.other_leader):
            self.client.force_login(member)
            self.assertEqual(self.send("patch", url, {"review_status": "checked"}).status_code, 403)

    def test_제출_파일은_제출자와_담당자만_내려받는다(self):
        submission_id = self.submit(self.create_assignment()).json()["id"]
        url = reverse("submission-download", args=[submission_id])
        expected = {
            self.member: 200,
            self.leader: 200,
            self.admin: 200,
            self.member2: 403,
            self.other_leader: 403,
            self.outsider: 403,
        }
        for member, status_code in expected.items():
            self.client.force_login(member)
            response = self.client.get(url)
            self.assertEqual(response.status_code, status_code, member.name)
            if status_code == 200:
                self.assertEqual(b"".join(response.streaming_content), make_zip())
        self.client.logout()
        self.assertEqual(self.client.get(url).status_code, 403)


class MyStudyDetailTests(StudyManageTestBase):
    def test_참여자는_회차별_내_출석과_과제를_본다(self):
        session = self.create_session(number=1, title="OT")
        Attendance.objects.create(session=session, participation=self.p1, status="late", note="스터디장 메모")
        Attendance.objects.create(session=session, participation=self.p2, status="absent")
        self.create_assignment()
        self.client.force_login(self.member)
        body = self.client.get(reverse("my-study-detail", args=[self.study.pk])).json()
        self.assertEqual(body["sessions"][0]["attendance"], "late")
        self.assertNotIn("note", body["sessions"][0])
        self.assertTrue(body["can_submit"])
        self.assertIsNone(body["assignments"][0]["submission"])

    def test_다른_참여자의_제출물은_보이지_않는다(self):
        assignment = self.create_assignment()
        self.client.force_login(self.member2)
        self.client.post(reverse("assignment-submit", args=[assignment.pk]), {"file": zip_upload()})
        self.client.force_login(self.member)
        body = self.client.get(reverse("my-study-detail", args=[self.study.pk])).json()
        self.assertIsNone(body["assignments"][0]["submission"])

    def test_참여하지_않은_스터디는_볼_수_없다(self):
        self.client.force_login(self.outsider)
        response = self.client.get(reverse("my-study-detail", args=[self.study.pk]))
        self.assertEqual(response.status_code, 404)
        self.assertEqual(response.json()["message"], "참여 중인 스터디가 아닙니다.")
