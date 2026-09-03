from django.urls import path
from .views import ParticipationUpdateView, SemesterListView, SemesterStudyListView, StudyDetailView

urlpatterns = [
    path("semesters/", SemesterListView.as_view(), name="semester-list"),
    path("semesters/<int:semester_id>/studies/", SemesterStudyListView.as_view(), name="semester-study-list"),
    path("studies/<int:pk>/", StudyDetailView.as_view(), name="study-detail"),
    path("studies/<int:study_id>/participations/<int:pk>/", ParticipationUpdateView.as_view(), name="participation-update"),
]

