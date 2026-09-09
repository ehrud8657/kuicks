from django.test import TestCase
from django.urls import reverse
from django.utils import timezone

from apps.accounts.models import Member
from .models import Post


def create_post(author, title, category=Post.Category.NOTICE, published_at=..., is_pinned=False):
    return Post.objects.create(
        category=category,
        title=title,
        content=f"{title} 본문",
        author=author,
        is_pinned=is_pinned,
        published_at=timezone.now() if published_at is ... else published_at,
    )


class PostListTests(TestCase):
    def setUp(self):
        self.author = Member.objects.create_user(
            student_id="2026320051", password="kuics!test", name="운영진", role=Member.Role.ADMIN
        )
        self.notice = create_post(self.author, "정기 총회 안내")
        self.recruit = create_post(self.author, "신입 부원 모집", category=Post.Category.RECRUIT)
        self.pinned = create_post(self.author, "필독 공지", is_pinned=True)

    def test_로그인_없이_목록을_볼_수_있다(self):
        response = self.client.get(reverse("post-list"))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["count"], 3)

    def test_카테고리로_거를_수_있다(self):
        response = self.client.get(reverse("post-list"), {"category": "recruit"})
        titles = [item["title"] for item in response.json()["results"]]
        self.assertEqual(titles, ["신입 부원 모집"])

    def test_고정글이_먼저_내려온다(self):
        response = self.client.get(reverse("post-list"))
        self.assertEqual(response.json()["results"][0]["title"], "필독 공지")

    def test_게시일이_없는_글은_보이지_않는다(self):
        """게시일을 비워두면 임시 저장(비공개)으로 취급된다."""
        create_post(self.author, "작성 중인 글", published_at=None)
        titles = [item["title"] for item in self.client.get(reverse("post-list")).json()["results"]]
        self.assertNotIn("작성 중인 글", titles)

    def test_예약_게시글은_아직_보이지_않는다(self):
        create_post(
            self.author,
            "다음 주 공지",
            published_at=timezone.now() + timezone.timedelta(days=7),
        )
        titles = [item["title"] for item in self.client.get(reverse("post-list")).json()["results"]]
        self.assertNotIn("다음 주 공지", titles)

    def test_상세에서_본문과_작성자를_준다(self):
        response = self.client.get(reverse("post-detail", args=[self.notice.pk]))
        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["content"], "정기 총회 안내 본문")
        self.assertEqual(payload["author_name"], "운영진")
