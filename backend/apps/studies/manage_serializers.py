from django.db.models import Count, F, Q
from rest_framework import serializers

from .models import Assignment, AssignmentSubmission, Attendance, Participation, Study, StudySession
from .serializers import leader_name

PENDING = AssignmentSubmission.ReviewStatus.PENDING


def with_assignment_counts(queryset):
    """과제 목록에 제출 수·지각 제출 수·미확인 수를 붙인다."""
    return queryset.annotate(
        submitted_count=Count("submissions", distinct=True),
        late_count=Count("submissions", filter=Q(submissions__submitted_at__gt=F("due_at")), distinct=True),
        unchecked_count=Count("submissions", filter=Q(submissions__review_status=PENDING), distinct=True),
    )


def with_participant_counts(queryset):
    """참여자 목록에 출석 상태별 횟수와 과제 제출 수를 붙인다."""
    counts = {
        f"{status}_count": Count("attendances", filter=Q(attendances__status=status), distinct=True)
        for status in Attendance.Status.values
    }
    return queryset.annotate(submitted_count=Count("submissions", distinct=True), **counts)


class ManageStudyListSerializer(serializers.ModelSerializer):
    semester = serializers.CharField(source="semester.name", read_only=True)
    leader_name = serializers.SerializerMethodField()
    participant_count = serializers.IntegerField(read_only=True)
    session_count = serializers.IntegerField(read_only=True)
    assignment_count = serializers.IntegerField(read_only=True)
    unchecked_count = serializers.IntegerField(read_only=True)

    def get_leader_name(self, study):
        return leader_name(study)

    class Meta:
        model = Study
        fields = (
            "id",
            "title",
            "semester",
            "leader_name",
            "participant_count",
            "session_count",
            "assignment_count",
            "unchecked_count",
        )


class ManageParticipantSerializer(serializers.ModelSerializer):
    """스터디장 화면의 참여자 행. 관리 화면이므로 학번 전체를 보여준다."""

    member_name = serializers.CharField(source="member.name", read_only=True)
    student_id = serializers.CharField(source="member.student_id", read_only=True)
    status_label = serializers.CharField(source="get_status_display", read_only=True)
    attendance = serializers.SerializerMethodField()
    submitted_count = serializers.IntegerField(read_only=True)

    def get_attendance(self, participation):
        return {status: getattr(participation, f"{status}_count", 0) for status in Attendance.Status.values}

    class Meta:
        model = Participation
        fields = ("id", "member_name", "student_id", "status", "status_label", "attendance", "submitted_count")


class StudySessionSerializer(serializers.ModelSerializer):
    number = serializers.IntegerField(min_value=1, required=False)
    recorded_count = serializers.IntegerField(read_only=True, default=0)

    def validate(self, attrs):
        study = self.instance.study if self.instance else self.context["view"].get_study()
        number = attrs.get("number")
        if number is not None:
            clash = StudySession.objects.filter(study=study, number=number)
            if self.instance:
                clash = clash.exclude(pk=self.instance.pk)
            if clash.exists():
                raise serializers.ValidationError({"number": [f"{number}회차가 이미 있습니다."]})
        return attrs

    class Meta:
        model = StudySession
        fields = ("id", "number", "title", "held_on", "recorded_count")


class AssignmentSerializer(serializers.ModelSerializer):
    submitted_count = serializers.IntegerField(read_only=True, default=0)
    late_count = serializers.IntegerField(read_only=True, default=0)
    unchecked_count = serializers.IntegerField(read_only=True, default=0)

    def validate_title(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError("제목을 입력해주세요.")
        return value

    class Meta:
        model = Assignment
        fields = ("id", "title", "description", "due_at", "submitted_count", "late_count", "unchecked_count")


class ManageStudyDetailSerializer(serializers.ModelSerializer):
    semester = serializers.CharField(source="semester.name", read_only=True)
    leader_name = serializers.SerializerMethodField()
    participants = serializers.SerializerMethodField()
    sessions = serializers.SerializerMethodField()
    assignments = serializers.SerializerMethodField()

    def get_leader_name(self, study):
        return leader_name(study)

    def get_participants(self, study):
        rows = with_participant_counts(study.participations.select_related("member")).order_by(
            "member__name", "member_id"
        )
        return ManageParticipantSerializer(rows, many=True).data

    def get_sessions(self, study):
        rows = study.sessions.annotate(recorded_count=Count("attendances"))
        return StudySessionSerializer(rows, many=True).data

    def get_assignments(self, study):
        return AssignmentSerializer(with_assignment_counts(study.assignments.all()), many=True).data

    class Meta:
        model = Study
        fields = ("id", "title", "semester", "leader_name", "description", "participants", "sessions", "assignments")


class AttendanceRecordInputSerializer(serializers.Serializer):
    participation_id = serializers.IntegerField()
    # null이면 해당 참여자의 출석 기록을 지운다(미기록 상태로 되돌리기).
    status = serializers.ChoiceField(choices=Attendance.Status.choices, allow_null=True)
    note = serializers.CharField(max_length=200, allow_blank=True, required=False, default="")


class AttendanceBulkSerializer(serializers.Serializer):
    records = AttendanceRecordInputSerializer(many=True, allow_empty=True)


class ManageSubmissionSerializer(serializers.ModelSerializer):
    is_late = serializers.BooleanField(read_only=True)
    reviewed_by_name = serializers.SerializerMethodField()

    def get_reviewed_by_name(self, submission):
        return submission.reviewed_by.name if submission.reviewed_by else None

    class Meta:
        model = AssignmentSubmission
        fields = (
            "id",
            "original_name",
            "size",
            "submitted_at",
            "is_late",
            "review_status",
            "feedback",
            "reviewed_at",
            "reviewed_by_name",
        )
        read_only_fields = ("original_name", "size", "submitted_at", "reviewed_at")
