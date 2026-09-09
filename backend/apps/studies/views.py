from rest_framework import generics, permissions
from .models import Participation, Semester, Study
from .permissions import IsAssignedLeaderOrAdmin
from .serializers import (
    MyStudySerializer,
    ParticipationSerializer,
    SemesterSerializer,
    StudySerializer,
)

class SemesterListView(generics.ListAPIView):
    queryset = Semester.objects.prefetch_related("studies__leader", "studies__participations__member").all()
    serializer_class = SemesterSerializer
    pagination_class = None

class SemesterStudyListView(generics.ListAPIView):
    serializer_class = StudySerializer
    pagination_class = None
    def get_queryset(self):
        return Study.objects.filter(semester_id=self.kwargs["semester_id"]).select_related("leader").prefetch_related("participations__member")

class StudyDetailView(generics.RetrieveAPIView):
    queryset = Study.objects.select_related("leader", "semester").prefetch_related("participations__member")
    serializer_class = StudySerializer

class ParticipationUpdateView(generics.UpdateAPIView):
    queryset = Participation.objects.select_related("study", "study__leader")
    serializer_class = ParticipationSerializer
    permission_classes = (permissions.IsAuthenticated, IsAssignedLeaderOrAdmin)
    http_method_names = ("patch", "options")


class MyStudyListView(generics.ListAPIView):
    """로그인 회원이 참여한 스터디 목록. 마이페이지의 수강 중/수료 스터디에 쓰인다."""

    serializer_class = MyStudySerializer
    permission_classes = (permissions.IsAuthenticated,)
    pagination_class = None

    def get_queryset(self):
        return (
            Participation.objects.filter(member=self.request.user)
            .select_related("study", "study__semester")
            .order_by("-study__semester__name", "study__title")
        )
