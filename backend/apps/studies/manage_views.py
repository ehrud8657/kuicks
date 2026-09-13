"""스터디장·운영진용 스터디 관리 API (/api/manage/...).

권한: 스터디장은 본인이 담당하는 스터디만, 운영진은 모든 스터디를 관리한다.
목록 접근은 IsStudyManager.has_permission, 개별 스터디 접근은 has_object_permission에서 확인한다.
"""

from django.db import IntegrityError, transaction
from django.db.models import Count, Max, Q
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import generics
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from .manage_serializers import (
    AssignmentSerializer,
    AttendanceBulkSerializer,
    ManageStudyDetailSerializer,
    ManageStudyListSerializer,
    ManageSubmissionSerializer,
    StudySessionSerializer,
    roster_count,
    with_assignment_counts,
)
from .models import Assignment, AssignmentSubmission, Attendance, Participation, Study, StudySession
from .permissions import IsStudyManager, can_manage_study, managed_studies

WITHDRAWN = Participation.Status.WITHDRAWN
COUNTED_STATUSES = [status for status in Participation.Status.values if status != WITHDRAWN]


def _roster(study):
    return study.participations.select_related("member").order_by("member__name", "member_id")


class ManageStudyListView(generics.ListAPIView):
    serializer_class = ManageStudyListSerializer
    permission_classes = (IsStudyManager,)
    pagination_class = None

    def get_queryset(self):
        pending = AssignmentSubmission.ReviewStatus.PENDING
        return (
            managed_studies(self.request.user)
            .select_related("semester", "leader")
            .annotate(
                # 중도 포기자는 참여자 수에서 뺀다.
                participant_count=Count(
                    "participations", filter=Q(participations__status__in=COUNTED_STATUSES), distinct=True
                ),
                session_count=Count("sessions", distinct=True),
                assignment_count=Count("assignments", distinct=True),
                unchecked_count=Count(
                    "assignments__submissions", filter=Q(assignments__submissions__review_status=pending), distinct=True
                ),
            )
            .order_by("-semester__name", "title")
        )


class ManageStudyDetailView(generics.RetrieveAPIView):
    queryset = Study.objects.select_related("semester", "leader")
    serializer_class = ManageStudyDetailSerializer
    permission_classes = (IsStudyManager,)


class ManageStudyAttendanceMatrixView(APIView):
    """참여자 × 회차 출석 현황표. statuses는 sessions 순서와 같은 길이의 목록이다."""

    permission_classes = (IsStudyManager,)

    def get(self, request, pk):
        study = get_object_or_404(Study, pk=pk)
        self.check_object_permissions(request, study)
        sessions = list(study.sessions.annotate(recorded_count=Count("attendances")))
        recorded = {
            (participation_id, session_id): status
            for participation_id, session_id, status in Attendance.objects.filter(session__study=study).values_list(
                "participation_id", "session_id", "status"
            )
        }
        rows = []
        for participation in _roster(study):
            statuses = [recorded.get((participation.pk, session.pk)) for session in sessions]
            if participation.status == WITHDRAWN and not any(statuses):
                continue
            rows.append(
                {
                    "participation_id": participation.pk,
                    "member_name": participation.member.name,
                    "student_id": participation.member.student_id,
                    "participation_status": participation.status,
                    "statuses": statuses,
                }
            )
        return Response({"sessions": StudySessionSerializer(sessions, many=True).data, "rows": rows})


class StudyChildMixin:
    """URL의 study_id로 스터디를 찾고, 관리 권한을 확인한다."""

    def get_study(self):
        if not hasattr(self, "_study"):
            study = get_object_or_404(Study, pk=self.kwargs["study_id"])
            if not can_manage_study(self.request.user, study):
                raise PermissionDenied("담당하는 스터디만 관리할 수 있습니다.")
            self._study = study
        return self._study


# ── 회차 ──────────────────────────────────────────────────────


class ManageSessionCreateView(StudyChildMixin, generics.CreateAPIView):
    serializer_class = StudySessionSerializer
    permission_classes = (IsStudyManager,)

    def perform_create(self, serializer):
        study = self.get_study()
        number = serializer.validated_data.get("number")
        if number is None:
            # 회차 번호를 비우면 마지막 회차 다음 번호를 쓴다.
            number = (study.sessions.aggregate(last=Max("number"))["last"] or 0) + 1
        try:
            serializer.save(study=study, number=number)
        except IntegrityError as exc:
            raise ValidationError({"number": [f"{number}회차가 이미 있습니다."]}) from exc


class ManageSessionDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = StudySession.objects.select_related("study").annotate(recorded_count=Count("attendances"))
    serializer_class = StudySessionSerializer
    permission_classes = (IsStudyManager,)
    http_method_names = ("get", "patch", "delete", "options")


class ManageSessionAttendanceView(APIView):
    """회차별 출석부. GET으로 조회하고 PUT으로 여러 명을 한 번에 저장한다."""

    permission_classes = (IsStudyManager,)

    def _get_session(self, pk):
        session = get_object_or_404(StudySession.objects.select_related("study"), pk=pk)
        self.check_object_permissions(self.request, session)
        return session

    def _payload(self, session):
        records = {record.participation_id: record for record in session.attendances.all()}
        rows = []
        for participation in _roster(session.study):
            record = records.get(participation.pk)
            # 중도 포기자는 기록이 남아 있을 때만 보여준다.
            if participation.status == WITHDRAWN and record is None:
                continue
            rows.append(
                {
                    "participation_id": participation.pk,
                    "member_name": participation.member.name,
                    "student_id": participation.member.student_id,
                    "participation_status": participation.status,
                    "status": record.status if record else None,
                    "note": record.note if record else "",
                }
            )
        session.recorded_count = len(records)
        return {"session": StudySessionSerializer(session).data, "records": rows}

    def get(self, request, pk):
        return Response(self._payload(self._get_session(pk)))

    def put(self, request, pk):
        session = self._get_session(pk)
        serializer = AttendanceBulkSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        records = serializer.validated_data["records"]

        roster_ids = set(session.study.participations.values_list("pk", flat=True))
        unknown = sorted({record["participation_id"] for record in records} - roster_ids)
        if unknown:
            raise ValidationError({"records": ["이 스터디의 참여자가 아닌 기록이 포함되어 있습니다."]})

        with transaction.atomic():
            for record in records:
                lookup = {"session": session, "participation_id": record["participation_id"]}
                if record["status"] is None:
                    Attendance.objects.filter(**lookup).delete()
                else:
                    Attendance.objects.update_or_create(
                        **lookup, defaults={"status": record["status"], "note": record.get("note", "")}
                    )
        return Response(self._payload(session))


# ── 과제 ──────────────────────────────────────────────────────


class ManageAssignmentCreateView(StudyChildMixin, generics.CreateAPIView):
    serializer_class = AssignmentSerializer
    permission_classes = (IsStudyManager,)

    def perform_create(self, serializer):
        serializer.save(study=self.get_study(), created_by=self.request.user)


class ManageAssignmentDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = AssignmentSerializer
    permission_classes = (IsStudyManager,)
    http_method_names = ("get", "patch", "delete", "options")

    def get_queryset(self):
        return with_assignment_counts(Assignment.objects.select_related("study"))

    def perform_update(self, serializer):
        serializer.save()
        # 기한이 바뀌면 지각 제출 수도 달라지므로 다시 센다.
        serializer.instance = self.get_queryset().get(pk=serializer.instance.pk)


class ManageAssignmentSubmissionsView(APIView):
    """과제 하나의 제출 현황. 참여자 전원을 행으로 주고, 미제출이면 submission이 null이다."""

    permission_classes = (IsStudyManager,)

    def get(self, request, pk):
        assignment = get_object_or_404(
            with_assignment_counts(Assignment.objects.select_related("study")), pk=pk
        )
        self.check_object_permissions(request, assignment)

        submissions = {
            submission.participation_id: submission
            for submission in assignment.submissions.select_related("reviewed_by", "assignment")
        }
        rows = []
        for participation in _roster(assignment.study):
            submission = submissions.get(participation.pk)
            # 중도 포기자는 제출물이 있을 때만 보여준다. (미제출자로 집계하지 않는다)
            if participation.status == WITHDRAWN and submission is None:
                continue
            rows.append(
                {
                    "participation_id": participation.pk,
                    "member_name": participation.member.name,
                    "student_id": participation.member.student_id,
                    "participation_status": participation.status,
                    "submission": ManageSubmissionSerializer(submission).data if submission else None,
                }
            )
        context = {"roster_count": roster_count(assignment.study)}
        return Response({"assignment": AssignmentSerializer(assignment, context=context).data, "rows": rows})


class ManageSubmissionReviewView(generics.UpdateAPIView):
    """제출물 확인 여부와 피드백."""

    queryset = AssignmentSubmission.objects.select_related("assignment__study", "reviewed_by")
    serializer_class = ManageSubmissionSerializer
    permission_classes = (IsStudyManager,)
    http_method_names = ("patch", "options")

    def perform_update(self, serializer):
        checked = serializer.validated_data.get("review_status", serializer.instance.review_status)
        if checked == AssignmentSubmission.ReviewStatus.CHECKED:
            serializer.save(reviewed_by=self.request.user, reviewed_at=timezone.now())
        else:
            serializer.save(reviewed_by=None, reviewed_at=None)
