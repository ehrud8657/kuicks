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
    queryset = Post.objects.filter(published_at__lte=timezone.now()).select_related("author")
    serializer_class = PostSerializer

