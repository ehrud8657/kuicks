import shutil
import tempfile
from pathlib import Path

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from django.urls import reverse

from apps.accounts.models import Member
from apps.studies.models import Semester

from .models import Activity, ActivityMember, Material, MaterialFile, Tag

TEMP_MEDIA = tempfile.mkdtemp(prefix="kuics-test-media-")


def create_member(student_id, name, role=Member.Role.MEMBER):
    return Member.objects.create_user(
        student_id=student_id, password="kuics!test", name=name, role=role, must_change_password=False
    )


@override_settings(MEDIA_ROOT=TEMP_MEDIA)
class ActivityTestBase(TestCase):
    """2026-2 프로젝트(팀장·팀원·휴회원 팀원), 2026-1 대회, 비공개 행사. 운영진과 외부 회원."""

    @classmethod
    def setUpTestData(cls):
        cls.fall = Semester.objects.create(name="2026-2")
        cls.spring = Semester.objects.create(name="2026-1")
        cls.web = Tag.objects.get(name="web")
        cls.leader = create_member("2026200001", "김팀장")
        cls.teammate = create_member("2026200002", "이팀원")
        cls.dormant = create_member("2026200003", "박휴회", role=Member.Role.DORMANT)
        cls.outsider = create_member("2026200004", "정외부")
        cls.admin = create_member("2026200005", "최운영", role=Member.Role.ADMIN)

        cls.project = Activity.objects.create(kind=Activity.Kind.PROJECT, semester=cls.fall, title="Team B")
        cls.project.tags.add(cls.web)
        ActivityMember.objects.create(activity=cls.project, member=cls.leader, role=ActivityMember.Role.LEADER)
        ActivityMember.objects.create(activity=cls.project, member=cls.teammate)
        ActivityMember.objects.create(activity=cls.project, member=cls.dormant)
        ActivityMember.objects.create(activity=cls.project, name="졸업생")
        cls.contest = Activity.objects.create(
            kind=Activity.Kind.CONTEST, semester=cls.spring, title="DEFCON Quals", result="32위"
        )
        cls.hidden = Activity.objects.create(
            kind=Activity.Kind.EVENT, semester=cls.fall, title="준비 중인 행사", is_published=False
        )

    @classmethod
    def tearDownClass(cls):
        super().tearDownClass()
        shutil.rmtree(TEMP_MEDIA, ignore_errors=True)

    def add_material(self, author=None, stage=Material.Stage.INTERIM, activity=None):
        return Material.objects.create(
            activity=activity or self.project, stage=stage, title="중간 발표", author=author or self.leader
        )

    def upload(self, material, name="slides.pdf", data=b"%PDF-1.4"):
        return self.client.post(
            reverse("material-file-create", args=[material.pk]),
            {"file": SimpleUploadedFile(name, data)},
        )


class ActivityReadTests(ActivityTestBase):
    def test_list_hides_unpublished_and_filters(self):
        response = self.client.get(reverse("activity-list"))
        self.assertEqual(response.status_code, 200)
        titles = [item["title"] for item in response.data["results"]]
        self.assertEqual(titles, ["Team B", "DEFCON Quals"])

        def titles_for(**query):
            return [item["title"] for item in self.client.get(reverse("activity-list"), query).data["results"]]

        self.assertEqual(titles_for(kind="contest"), ["DEFCON Quals"])
        self.assertEqual(titles_for(semester="2026-2"), ["Team B"])
        self.assertEqual(titles_for(tag="web"), ["Team B"])

    def test_list_summarizes_members_and_stages(self):
        self.add_material(stage=Material.Stage.FINAL)
        self.add_material(stage=Material.Stage.INTERIM)
        item = self.client.get(reverse("activity-list"), {"kind": "project"}).data["results"][0]
        self.assertEqual(item["material_count"], 2)
        self.assertEqual(item["stages"], ["interim", "final"])
        self.assertEqual(item["tags"], ["web"])
        # 팀장이 먼저, 계정 없이 이름만 적은 참여자도 나오고, 학번은 내려보내지 않는다.
        self.assertEqual(item["members"][0], {"name": "김팀장", "role": "leader"})
        self.assertIn({"name": "졸업생", "role": "member"}, item["members"])

    def test_filters_only_list_semesters_and_tags_in_use(self):
        Tag.objects.create(name="unused")
        response = self.client.get(reverse("activity-filters"))
        self.assertEqual(response.data["semesters"], ["2026-2", "2026-1"])
        self.assertEqual(response.data["tags"], ["web"])

    def test_detail_is_public_and_unpublished_is_404(self):
        material = self.add_material()
        response = self.client.get(reverse("activity-detail", args=[self.project.pk]))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["materials"][0]["id"], material.pk)
        self.assertEqual(response.data["materials"][0]["author_name"], "김팀장")
        self.assertFalse(response.data["can_contribute"])
        self.assertFalse(response.data["materials"][0]["can_edit"])
        self.assertEqual(self.client.get(reverse("activity-detail", args=[self.hidden.pk])).status_code, 404)

    def test_can_contribute_flag(self):
        url = reverse("activity-detail", args=[self.project.pk])
        for member, expected in (
            (self.leader, True), (self.teammate, True), (self.admin, True),
            (self.dormant, False), (self.outsider, False),
        ):
            self.client.force_login(member)
            self.assertEqual(self.client.get(url).data["can_contribute"], expected, member.name)

    def test_member_name_survives_account_deletion(self):
        material = self.add_material()
        self.leader.delete()
        response = self.client.get(reverse("activity-detail", args=[self.project.pk]))
        self.assertIn({"name": "김팀장", "role": "leader"}, response.data["members"])
        self.assertEqual(response.data["materials"][0]["author_name"], "김팀장")
        material.refresh_from_db()
        self.assertIsNone(material.author)


class MaterialWriteTests(ActivityTestBase):
    def create(self, activity=None, **data):
        payload = {"stage": "interim", "title": "중간 발표", "description": "https://github.com/kuics/fuzz"}
        payload.update(data)
        return self.client.post(
            reverse("material-create", args=[(activity or self.project).pk]), payload, content_type="application/json"
        )

    def test_participant_creates_material(self):
        self.client.force_login(self.teammate)
        response = self.create()
        self.assertEqual(response.status_code, 201)
        material = Material.objects.get(pk=response.data["id"])
        self.assertEqual(material.author, self.teammate)
        self.assertEqual(material.author_name, "이팀원")
        self.assertTrue(response.data["can_edit"])

    def test_who_cannot_create(self):
        self.assertEqual(self.create().status_code, 403)  # 로그인 안 함
        for member in (self.outsider, self.dormant):
            self.client.force_login(member)
            self.assertEqual(self.create().status_code, 403, member.name)
        self.assertFalse(Material.objects.exists())

    def test_admin_creates_on_any_activity(self):
        self.client.force_login(self.admin)
        self.assertEqual(self.create(activity=self.contest).status_code, 201)

    def test_unpublished_activity_is_404(self):
        self.client.force_login(self.admin)
        self.assertEqual(self.create(activity=self.hidden).status_code, 404)

    def test_blank_title_rejected(self):
        self.client.force_login(self.leader)
        response = self.create(title="   ")
        self.assertEqual(response.status_code, 400)

    def test_archived_activity_is_admin_only(self):
        self.project.status = Activity.Status.ARCHIVED
        self.project.save()
        material = self.add_material(author=self.leader)
        self.client.force_login(self.leader)
        self.assertEqual(self.create().status_code, 403)
        url = reverse("material-detail", args=[material.pk])
        self.assertEqual(self.client.delete(url).status_code, 403)
        self.client.force_login(self.admin)
        self.assertEqual(self.create().status_code, 201)

    def test_only_author_or_admin_edits(self):
        material = self.add_material(author=self.leader)
        url = reverse("material-detail", args=[material.pk])
        self.client.force_login(self.teammate)
        self.assertEqual(
            self.client.patch(url, {"title": "바꿈"}, content_type="application/json").status_code, 403
        )
        self.client.force_login(self.leader)
        response = self.client.patch(url, {"title": "중간 발표 (수정)"}, content_type="application/json")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["title"], "중간 발표 (수정)")
        self.client.force_login(self.admin)
        self.assertEqual(self.client.delete(url).status_code, 204)
        self.assertFalse(Material.objects.exists())


class MaterialFileTests(ActivityTestBase):
    def test_upload_download_delete(self):
        material = self.add_material(author=self.leader)
        self.client.force_login(self.leader)
        response = self.upload(material, name="최종 보고서.pdf")
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data["name"], "최종 보고서.pdf")
        attachment = MaterialFile.objects.get(pk=response.data["id"])
        path = Path(attachment.file.path)
        self.assertTrue(path.exists())
        self.assertNotIn("보고서", path.name)

        # 누구나 받을 수 있고, 사진이 아니면 항상 내려받기로 나간다.
        self.client.logout()
        download = self.client.get(reverse("activity-file", args=[attachment.pk]))
        self.assertEqual(download.status_code, 200)
        self.assertIn("attachment", download["Content-Disposition"])
        self.assertEqual(download["Content-Type"], "application/octet-stream")
        self.assertEqual(b"".join(download.streaming_content), b"%PDF-1.4")

        self.client.force_login(self.teammate)
        self.assertEqual(self.client.delete(reverse("activity-file", args=[attachment.pk])).status_code, 403)
        self.client.force_login(self.leader)
        self.assertEqual(self.client.delete(reverse("activity-file", args=[attachment.pk])).status_code, 204)
        self.assertFalse(path.exists())

    def test_image_is_inline_and_svg_is_download(self):
        material = self.add_material()
        self.client.force_login(self.leader)
        png = MaterialFile.objects.get(pk=self.upload(material, name="사진.png", data=b"\x89PNG").data["id"])
        svg = MaterialFile.objects.get(pk=self.upload(material, name="x.svg", data=b"<svg/>").data["id"])
        self.assertIn("inline", self.client.get(reverse("activity-file", args=[png.pk]))["Content-Disposition"])
        response = self.client.get(reverse("activity-file", args=[svg.pk]))
        self.assertIn("attachment", response["Content-Disposition"])
        self.assertEqual(response["Content-Type"], "application/octet-stream")

    def test_outsider_cannot_upload(self):
        material = self.add_material()
        self.client.force_login(self.outsider)
        self.assertEqual(self.upload(material).status_code, 403)

    @override_settings(ACTIVITY_FILE_MAX_BYTES=4)
    def test_too_large_rejected(self):
        material = self.add_material()
        self.client.force_login(self.leader)
        response = self.upload(material, data=b"12345")
        self.assertEqual(response.status_code, 400)
        self.assertFalse(MaterialFile.objects.exists())

    def test_deleting_activity_removes_files(self):
        material = self.add_material()
        self.client.force_login(self.leader)
        attachment = MaterialFile.objects.get(pk=self.upload(material).data["id"])
        path = Path(attachment.file.path)
        self.project.delete()
        self.assertFalse(path.exists())

    def test_files_of_unpublished_activity_are_hidden(self):
        material = self.add_material(activity=self.hidden, author=self.admin)
        attachment = MaterialFile.objects.create(material=material, file=SimpleUploadedFile("a.pdf", b"x"))
        self.assertEqual(self.client.get(reverse("activity-file", args=[attachment.pk])).status_code, 404)
