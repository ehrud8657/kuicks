from rest_framework import generics, permissions
from .models import Participation, Semester, Study
from .permissions import IsAssignedLeaderOrAdmin
from .serializers import ParticipationSerializer, SemesterSerializer, StudySerializer

class SemesterListView(generics.ListAPIView):
    queryset = Semester.objects.prefetch_related("studies__participations__member").all()
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

