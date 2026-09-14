from django.test import Client, TestCase
from django.urls import reverse

from .models import Member

NEW_PASSWORD = "Kuics-new-2026!"


def post_json(client, url, data=None):
    return client.post(url, data or {}, content_type="application/json")


class LoginTests(TestCase):
    def setUp(self):
        self.member = Member.objects.create_user(
            student_id="2026320090", name="로그인", password="kuics!2026320090"
        )

    def test_학번과_초기_비밀번호로_로그인한다(self):
        response = post_json(
            self.client, reverse("login"), {"student_id": "2026320090", "password": "kuics!2026320090"}
        )
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()["must_change_password"])

    def test_비밀번호가_틀리면_통일된_오류_형식으로_응답한다(self):
        response = post_json(self.client, reverse("login"), {"student_id": "2026320090", "password": "wrong"})
        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json()["code"], "invalid_credentials")


class PasswordChangeRequiredApiTests(TestCase):
    """초기 비밀번호를 바꾸기 전에는 로그인이 필요한 API를 쓸 수 없다."""

    def setUp(self):
        self.member = Member.objects.create_user(
            student_id="2026320099", name="새회원", password="kuics!2026320099"
        )
        self.client.force_login(self.member)

    def test_새_회원은_비밀번호_변경이_필요한_상태로_만들어진다(self):
        self.assertTrue(self.member.must_change_password)

    def test_본인_정보는_조회할_수_있다(self):
        response = self.client.get(reverse("me"))
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()["must_change_password"])

    def test_로그인이_필요한_API는_막힌다(self):
        response = self.client.get(reverse("my-study-list"))
        self.assertEqual(response.status_code, 403)
        self.assertEqual(response.json()["code"], "password_change_required")

    def test_공개_API는_그대로_열린다(self):
        self.assertEqual(self.client.get(reverse("semester-list")).status_code, 200)
        self.assertEqual(self.client.get(reverse("post-list")).status_code, 200)

    def test_비밀번호를_바꾸면_API를_쓸_수_있다(self):
        response = post_json(self.client, reverse("change-password"), {"new_password": NEW_PASSWORD})
        self.assertEqual(response.status_code, 200)
        self.member.refresh_from_db()
        self.assertFalse(self.member.must_change_password)
        self.assertEqual(self.client.get(reverse("my-study-list")).status_code, 200)

    def test_초기_비밀번호를_그대로_다시_쓸_수_없다(self):
        response = post_json(self.client, reverse("change-password"), {"new_password": "kuics!2026320099"})
        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json()["code"], "invalid_password")
        self.member.refresh_from_db()
        self.assertTrue(self.member.must_change_password)

    def test_규칙에_맞지_않는_비밀번호는_거절한다(self):
        response = post_json(self.client, reverse("change-password"), {"new_password": "short"})
        self.assertEqual(response.status_code, 400)
        self.assertIn("new_password", response.json()["fields"])

    def test_로그아웃은_할_수_있다(self):
        self.assertEqual(self.client.post(reverse("logout")).status_code, 204)

    def test_CSRF_토큰_없이는_비밀번호를_바꿀_수_없다(self):
        client = Client(enforce_csrf_checks=True)
        client.force_login(self.member)
        response = post_json(client, reverse("change-password"), {"new_password": NEW_PASSWORD})
        self.assertEqual(response.status_code, 403)


class PasswordChangeRequiredAdminTests(TestCase):
    def test_비밀번호를_바꾸지_않은_운영진은_관리자_페이지가_막힌다(self):
        admin = Member.objects.create_user(
            student_id="2026000001", name="운영진", password="kuics!2026000001", role=Member.Role.ADMIN
        )
        self.client.force_login(admin)
        response = self.client.get("/admin/")
        self.assertContains(response, "비밀번호를 먼저 변경해주세요", status_code=403)

    def test_비밀번호를_바꾼_운영진은_관리자_페이지에_들어갈_수_있다(self):
        admin = Member.objects.create_user(
            student_id="2026000002",
            name="운영진",
            password=NEW_PASSWORD,
            role=Member.Role.ADMIN,
            must_change_password=False,
        )
        self.client.force_login(admin)
        self.assertEqual(self.client.get("/admin/").status_code, 200)

    def test_createsuperuser로_만든_계정은_변경_강제_대상이_아니다(self):
        user = Member.objects.create_superuser(student_id="2026000003", name="관리자", password=NEW_PASSWORD)
        self.assertFalse(user.must_change_password)
        self.assertEqual(user.role, Member.Role.ADMIN)
        self.assertTrue(user.is_superuser)


class ApiErrorFormatTests(TestCase):
    def test_로그인하지_않은_요청은_통일된_오류_형식으로_응답한다(self):
        response = self.client.get(reverse("me"))
        self.assertEqual(response.status_code, 403)
        body = response.json()
        self.assertEqual(body["code"], "not_authenticated")
        self.assertEqual(body["message"], "로그인이 필요합니다. 다시 로그인해주세요.")
        self.assertIsNone(body["fields"])

    def test_없는_리소스는_not_found로_응답한다(self):
        response = self.client.get(reverse("post-detail", args=[9999]))
        self.assertEqual(response.status_code, 404)
        self.assertEqual(response.json()["code"], "not_found")
