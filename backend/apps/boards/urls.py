from django.urls import path
from .views import PostAttachmentView, PostDetailView, PostListView
urlpatterns = [
    path("boards/", PostListView.as_view(), name="post-list"),
    path("boards/<int:pk>/", PostDetailView.as_view(), name="post-detail"),
    path("boards/attachments/<int:pk>/", PostAttachmentView.as_view(), name="post-attachment"),
]
