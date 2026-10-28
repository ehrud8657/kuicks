from django.urls import path

from .views import (
    ActivityDetailView,
    ActivityFilterView,
    ActivityListView,
    MaterialCreateView,
    MaterialDetailView,
    MaterialFileCreateView,
    MaterialFileView,
)

urlpatterns = [
    path("activities/", ActivityListView.as_view(), name="activity-list"),
    path("activities/filters/", ActivityFilterView.as_view(), name="activity-filters"),
    path("activities/<int:pk>/", ActivityDetailView.as_view(), name="activity-detail"),
    path("activities/<int:activity_id>/materials/", MaterialCreateView.as_view(), name="material-create"),
    path("activities/materials/<int:pk>/", MaterialDetailView.as_view(), name="material-detail"),
    path("activities/materials/<int:pk>/files/", MaterialFileCreateView.as_view(), name="material-file-create"),
    path("activities/files/<int:pk>/", MaterialFileView.as_view(), name="activity-file"),
]
