import os
import shutil
import tempfile

from django.core.exceptions import ValidationError
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from django.urls import reverse
from django.utils import timezone

from apps.accounts.models import Member
from .models import Post, PostAttachment

# 1x1 투명 PNG. 실제 이미지 바이트여야 FileResponse가 그대로 흘려보낼 수 있다.
PNG_BYTES = bytes.fromhex(
    "89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c489"
    "0000000a49444154789c63000100000500010d0a2db40000000049454e44ae426082"
)

_MEDIA = tempfile.mkdtemp(prefix="kuics-test-media-")


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

    def test_게시일을_지정하지_않으면_바로_게시된다(self):
        """운영진이 Admin에서 게시일을 건드리지 않고 저장하는 경우."""
        Post.objects.create(
            category=Post.Category.NOTICE,
            title="바로 올린 공지",
            content="본문",
            author=self.author,
        )
        titles = [item["title"] for item in self.client.get(reverse("post-list")).json()["results"]]
        self.assertIn("바로 올린 공지", titles)

    def test_게시일을_비우면_보이지_않는다(self):
        """게시일을 명시적으로 비우면 임시 저장(비공개)으로 취급된다."""
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



@override_settings(MEDIA_ROOT=_MEDIA)
class PostAttachmentTests(TestCase):
    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(_MEDIA, ignore_errors=True)
        super().tearDownClass()

    def setUp(self):
        self.author = Member.objects.create_user(
            student_id="2026320051", password="kuics!test", name="운영진", role=Member.Role.ADMIN
        )
        self.post = create_post(self.author, "스터디 신청 안내")

    def attach(self, post, name="포스터.png", content=PNG_BYTES):
        return PostAttachment.objects.create(
            post=post, file=SimpleUploadedFile(name, content)
        )

    def test_첨부가_없으면_빈_목록이_내려온다(self):
        payload = self.client.get(reverse("post-detail", args=[self.post.pk])).json()
        self.assertEqual(payload["attachments"], [])

    def test_첨부를_올리면_이름과_크기가_함께_내려온다(self):
        self.attach(self.post)
        payload = self.client.get(reverse("post-detail", args=[self.post.pk])).json()
        self.assertEqual(len(payload["attachments"]), 1)
        item = payload["attachments"][0]
        self.assertEqual(item["name"], "포스터.png")
        self.assertEqual(item["size"], len(PNG_BYTES))
        self.assertTrue(item["is_image"])
        self.assertIn("/boards/attachments/", item["url"])

    def test_원본_파일명은_저장_경로에_쓰지_않는다(self):
        """한글 파일명이 서버 파일시스템에서 깨지거나 서로 덮어쓰는 것을 막는다."""
        attachment = self.attach(self.post, name="2026-2학기 모집.png")
        self.assertNotIn("모집", attachment.file.name)
        self.assertTrue(attachment.file.name.endswith(".png"))
        self.assertEqual(attachment.original_name, "2026-2학기 모집.png")

    def test_사진은_화면에_바로_보이도록_내려온다(self):
        attachment = self.attach(self.post)
        response = self.client.get(reverse("post-attachment", args=[attachment.pk]))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response["Content-Type"], "image/png")
        self.assertNotIn("attachment;", response.get("Content-Disposition", ""))

    def test_문서는_내려받기로_나간다(self):
        attachment = self.attach(self.post, name="회칙.pdf", content=b"%PDF-1.4 ...")
        response = self.client.get(reverse("post-attachment", args=[attachment.pk]))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response["Content-Type"], "application/pdf")
        self.assertIn("attachment;", response["Content-Disposition"])

    def test_사진도_download_1이면_내려받기가_된다(self):
        attachment = self.attach(self.post)
        response = self.client.get(reverse("post-attachment", args=[attachment.pk]), {"download": "1"})
        self.assertIn("attachment;", response["Content-Disposition"])

    def test_미공개_글의_첨부는_주소를_알아도_받을_수_없다(self):
        draft = create_post(self.author, "작성 중인 글", published_at=None)
        attachment = self.attach(draft)
        response = self.client.get(reverse("post-attachment", args=[attachment.pk]))
        self.assertEqual(response.status_code, 404)

    def test_예약_게시글의_첨부도_아직_받을_수_없다(self):
        scheduled = create_post(
            self.author, "다음 주 공지", published_at=timezone.now() + timezone.timedelta(days=7)
        )
        attachment = self.attach(scheduled)
        self.assertEqual(
            self.client.get(reverse("post-attachment", args=[attachment.pk])).status_code, 404
        )

    def test_운영진은_미공개_글의_첨부를_미리_볼_수_있다(self):
        """Admin에서 글을 쓰는 중에 미리보기가 떠야 한다."""
        self.author.must_change_password = False
        self.author.save()
        self.client.force_login(self.author)
        draft = create_post(self.author, "작성 중인 글", published_at=None)
        attachment = self.attach(draft)
        self.assertEqual(
            self.client.get(reverse("post-attachment", args=[attachment.pk])).status_code, 200
        )

    def test_실행_파일은_올릴_수_없다(self):
        attachment = PostAttachment(post=self.post, file=SimpleUploadedFile("setup.exe", b"MZ"))
        with self.assertRaises(ValidationError) as caught:
            attachment.clean()
        self.assertIn("file", caught.exception.message_dict)

    @override_settings(BOARD_ATTACHMENT_MAX_BYTES=10)
    def test_너무_큰_파일은_올릴_수_없다(self):
        attachment = PostAttachment(post=self.post, file=SimpleUploadedFile("큰사진.png", b"x" * 50))
        with self.assertRaises(ValidationError) as caught:
            attachment.clean()
        self.assertIn("file", caught.exception.message_dict)

    def test_글을_지우면_첨부도_함께_사라진다(self):
        attachment = self.attach(self.post)
        path = attachment.file.path
        self.post.delete()
        self.assertEqual(PostAttachment.objects.count(), 0)
        # 기록만 지우고 파일이 남으면 디스크가 계속 불어난다.
        self.assertFalse(os.path.exists(path))

    def test_첨부만_지워도_파일이_남지_않는다(self):
        attachment = self.attach(self.post)
        path = attachment.file.path
        attachment.delete()
        self.assertFalse(os.path.exists(path))
