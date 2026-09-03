from rest_framework import serializers
from .models import Post
class PostSerializer(serializers.ModelSerializer):
    author_name = serializers.CharField(source="author.name", read_only=True)
    class Meta:
        model = Post
        fields = ("id", "category", "title", "content", "author_name", "is_pinned", "published_at")

