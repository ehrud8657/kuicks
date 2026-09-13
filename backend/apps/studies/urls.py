from django.urls import path

from . import manage_views
from .views import (
    AssignmentSubmitView,
    MyStudyDetailView,
    MyStudyListView,
    ParticipationUpdateView,
    SemesterListView,
    SemesterStudyListView,
    StudyDetailView,
    SubmissionDownloadView,
)

urlpatterns = [
    path("me/studies/", MyStudyListView.as_view(), name="my-study-list"),
    path("me/studies/<int:study_id>/", MyStudyDetailView.as_view(), name="my-study-detail"),
    path("semesters/", SemesterListView.as_view(), name="semester-list"),
    path("semesters/<int:semester_id>/studies/", SemesterStudyListView.as_view(), name="semester-study-list"),
    path("studies/<int:pk>/", StudyDetailView.as_view(), name="study-detail"),
    path("studies/<int:study_id>/participations/<int:pk>/", ParticipationUpdateView.as_view(), name="participation-update"),
    path("assignments/<int:pk>/submissions/", AssignmentSubmitView.as_view(), name="assignment-submit"),
    path("submissions/<int:pk>/download/", SubmissionDownloadView.as_view(), name="submission-download"),
    # 스터디장·운영진용
    path("manage/studies/", manage_views.ManageStudyListView.as_view(), name="manage-study-list"),
    path("manage/studies/<int:pk>/", manage_views.ManageStudyDetailView.as_view(), name="manage-study-detail"),
    path(
        "manage/studies/<int:pk>/attendance/",
        manage_views.ManageStudyAttendanceMatrixView.as_view(),
        name="manage-study-attendance",
    ),
    path(
        "manage/studies/<int:study_id>/sessions/",
        manage_views.ManageSessionCreateView.as_view(),
        name="manage-session-create",
    ),
    path("manage/sessions/<int:pk>/", manage_views.ManageSessionDetailView.as_view(), name="manage-session-detail"),
    path(
        "manage/sessions/<int:pk>/attendance/",
        manage_views.ManageSessionAttendanceView.as_view(),
        name="manage-session-attendance",
    ),
    path(
        "manage/studies/<int:study_id>/assignments/",
        manage_views.ManageAssignmentCreateView.as_view(),
        name="manage-assignment-create",
    ),
    path(
        "manage/assignments/<int:pk>/",
        manage_views.ManageAssignmentDetailView.as_view(),
        name="manage-assignment-detail",
    ),
    path(
        "manage/assignments/<int:pk>/submissions/",
        manage_views.ManageAssignmentSubmissionsView.as_view(),
        name="manage-assignment-submissions",
    ),
    path(
        "manage/submissions/<int:pk>/",
        manage_views.ManageSubmissionReviewView.as_view(),
        name="manage-submission-review",
    ),
]
