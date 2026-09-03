from django.urls import path
from .views import PostDetailView, PostListView
urlpatterns = [
    path("boards/", PostListView.as_view(), name="post-list"),
    path("boards/<int:pk>/", PostDetailView.as_view(), name="post-detail"),
]

