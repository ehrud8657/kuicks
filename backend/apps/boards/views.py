from django.http import FileResponse
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import generics
from rest_framework.exceptions import NotFound
from rest_framework.views import APIView

from .models import Post, PostAttachment
from .serializers import PostSerializer


def published_posts():
    """공개된 게시글만. 게시일이 비었거나 미래인 글은 아직 보이지 않는다."""
    return Post.objects.filter(published_at__lte=timezone.now())


class PostListView(generics.ListAPIView):
    serializer_class = PostSerializer

    def get_queryset(self):
        queryset = published_posts().select_related("author").prefetch_related("attachments")
        category = self.request.query_params.get("category")
        return queryset.filter(category=category) if category else queryset


class PostDetailView(generics.RetrieveAPIView):
    serializer_class = PostSerializer

    def get_queryset(self):
        # timezone.now()를 클래스 속성에 두면 프로세스가 시작된 시각으로 고정되어,
        # 그 뒤에 게시된 글이 서버를 재시작할 때까지 계속 404가 된다.
        # 요청마다 다시 평가되도록 get_queryset()에서 계산한다.
        return published_posts().select_related("author").prefetch_related("attachments")


class PostAttachmentView(APIView):
    """게시글 첨부 내려주기.

    게시글 자체가 공개이므로 로그인 없이 받을 수 있지만, 아직 공개되지 않은 글
    (임시 저장·예약 게시)의 첨부는 주소를 알아도 받을 수 없다. 운영진만 예외다.

    사진은 그대로 화면에 띄워야 하므로 기본은 inline이고, ?download=1이면 내려받기가 된다.
    """

    def get(self, request, pk):
        queryset = PostAttachment.objects.select_related("post")
        # 운영진은 Admin에서 미리보기를 해야 하므로 아직 공개하지 않은 글의 첨부도 볼 수 있다.
        if not (request.user.is_authenticated and request.user.is_staff):
            queryset = queryset.filter(post__in=published_posts())
        attachment = get_object_or_404(queryset, pk=pk)
        try:
            handle = attachment.file.storage.open(attachment.file.name, "rb")
        except FileNotFoundError as exc:
            raise NotFound("파일을 찾을 수 없습니다. 서버 저장소가 초기화되었을 수 있습니다.") from exc
        as_attachment = request.query_params.get("download") == "1" or not attachment.is_image
        return FileResponse(
            handle,
            as_attachment=as_attachment,
            filename=attachment.original_name,
            content_type=attachment.content_type or "application/octet-stream",
        )
