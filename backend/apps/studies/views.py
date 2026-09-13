from django.http import FileResponse
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.exceptions import NotFound, PermissionDenied
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView

from .files import validate_submission_file
from .models import Assignment, AssignmentSubmission, Participation, Semester, Study
from .permissions import IsAssignedLeaderOrAdmin, can_manage_study
from .serializers import (
    MyAssignmentSerializer,
    MySessionSerializer,
    MyStudySerializer,
    MySubmissionSerializer,
    ParticipationSerializer,
    SemesterSerializer,
    StudySerializer,
    leader_name,
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
    serializer_class = ParticipationSerializer
    permission_classes = (permissions.IsAuthenticated, IsAssignedLeaderOrAdmin)
    http_method_names = ("patch", "options")

    def get_queryset(self):
        # URL의 스터디에 속한 참여 기록만 대상으로 한다.
        return Participation.objects.select_related("study", "study__leader", "member").filter(
            study_id=self.kwargs["study_id"]
        )


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


class MyStudyDetailView(APIView):
    """참여자 본인의 스터디 상세: 회차별 내 출석, 과제와 내 제출 상태."""

    permission_classes = (permissions.IsAuthenticated,)

    def get(self, request, study_id):
        participation = (
            Participation.objects.select_related("study__semester", "study__leader")
            .filter(member=request.user, study_id=study_id)
            .first()
        )
        if participation is None:
            raise NotFound("참여 중인 스터디가 아닙니다.")
        study = participation.study
        context = {
            "attendance": {record.session_id: record.status for record in participation.attendances.all()},
            "submissions": {
                submission.assignment_id: submission
                for submission in participation.submissions.select_related("assignment")
            },
        }
        return Response(
            {
                "study": {
                    "id": study.pk,
                    "title": study.title,
                    "semester": study.semester.name,
                    "leader_name": leader_name(study),
                    "description": study.description,
                },
                "participation": {
                    "id": participation.pk,
                    "status": participation.status,
                    "status_label": participation.get_status_display(),
                },
                "can_submit": participation.status == Participation.Status.ACTIVE,
                "sessions": MySessionSerializer(study.sessions.all(), many=True, context=context).data,
                "assignments": MyAssignmentSerializer(study.assignments.all(), many=True, context=context).data,
            }
        )


class AssignmentSubmitView(APIView):
    """zip 파일로 과제를 제출한다. 이미 제출했다면 파일을 교체하고 확인 상태를 초기화한다."""

    permission_classes = (permissions.IsAuthenticated,)
    parser_classes = (MultiPartParser, FormParser)

    def post(self, request, pk):
        assignment = get_object_or_404(Assignment.objects.select_related("study"), pk=pk)
        participation = Participation.objects.filter(member=request.user, study=assignment.study).first()
        if participation is None:
            raise PermissionDenied("이 스터디의 참여자만 제출할 수 있습니다.")
        if participation.status != Participation.Status.ACTIVE:
            raise PermissionDenied("수강 중인 참여자만 제출할 수 있습니다.")

        upload = request.FILES.get("file")
        validate_submission_file(upload)

        submission = AssignmentSubmission.objects.filter(assignment=assignment, participation=participation).first()
        created = submission is None
        previous_file = None if created else submission.file.name
        if created:
            submission = AssignmentSubmission(assignment=assignment, participation=participation)

        submission.file = upload
        submission.original_name = upload.name[-255:]
        submission.size = upload.size
        submission.submitted_at = timezone.now()
        # 새 파일은 다시 확인해야 한다. 피드백은 이전 내용을 참고할 수 있게 남겨둔다.
        submission.review_status = AssignmentSubmission.ReviewStatus.PENDING
        submission.reviewed_at = None
        submission.reviewed_by = None
        submission.save()

        if previous_file and previous_file != submission.file.name:
            submission.file.storage.delete(previous_file)

        return Response(
            MySubmissionSerializer(submission).data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


class SubmissionDownloadView(APIView):
    """제출 파일 내려받기. 제출자 본인과 해당 스터디의 스터디장·운영진만 받을 수 있다.

    제출물은 공개 /media/ 경로로 서빙하지 않고 반드시 이 API로만 내보낸다.
    """

    permission_classes = (permissions.IsAuthenticated,)

    def get(self, request, pk):
        submission = get_object_or_404(
            AssignmentSubmission.objects.select_related("participation", "assignment__study"), pk=pk
        )
        is_owner = submission.participation.member_id == request.user.pk
        if not (is_owner or can_manage_study(request.user, submission.assignment.study)):
            raise PermissionDenied("이 제출물을 내려받을 권한이 없습니다.")
        try:
            handle = submission.file.storage.open(submission.file.name, "rb")
        except FileNotFoundError as exc:
            raise NotFound("파일을 찾을 수 없습니다. 서버 저장소가 초기화되었을 수 있습니다.") from exc
        return FileResponse(
            handle, as_attachment=True, filename=submission.original_name, content_type="application/zip"
        )
