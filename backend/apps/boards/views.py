from django.utils import timezone
from rest_framework import generics
from .models import Post
from .serializers import PostSerializer
class PostListView(generics.ListAPIView):
    serializer_class = PostSerializer
    def get_queryset(self):
        queryset = Post.objects.filter(published_at__lte=timezone.now()).select_related("author")
        category = self.request.query_params.get("category")
        return queryset.filter(category=category) if category else queryset
class PostDetailView(generics.RetrieveAPIView):
    serializer_class = PostSerializer
    def get_queryset(self):
        # timezone.now()를 클래스 속성에 두면 프로세스가 시작된 시각으로 고정되어,
        # 그 뒤에 게시된 글이 서버를 재시작할 때까지 계속 404가 된다.
        # 요청마다 다시 평가되도록 get_queryset()에서 계산한다.
        return Post.objects.filter(published_at__lte=timezone.now()).select_related("author")

