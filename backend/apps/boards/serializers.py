from django.urls import reverse
from rest_framework import serializers

from .models import Post, PostAttachment


class PostAttachmentSerializer(serializers.ModelSerializer):
    name = serializers.CharField(source="original_name", read_only=True)
    is_image = serializers.BooleanField(read_only=True)
    url = serializers.SerializerMethodField()

    class Meta:
        model = PostAttachment
        fields = ("id", "name", "size", "content_type", "is_image", "url")

    def get_url(self, attachment):
        # 첨부는 /media/로 공개하지 않고 이 API로만 내보낸다(과제 제출물과 같은 원칙).
        path = reverse("post-attachment", args=[attachment.pk])
        request = self.context.get("request")
        return request.build_absolute_uri(path) if request else path


class PostSerializer(serializers.ModelSerializer):
    author_name = serializers.CharField(source="author.name", read_only=True)
    attachments = PostAttachmentSerializer(many=True, read_only=True)

    class Meta:
        model = Post
        fields = (
            "id", "category", "title", "content", "author_name",
            "is_pinned", "published_at", "attachments",
        )
