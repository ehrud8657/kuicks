from django.utils import timezone
from rest_framework import serializers

from .models import Assignment, AssignmentSubmission, Participation, Semester, Study, StudySession

LEADER_UNASSIGNED = "미정"


def leader_name(study):
    # 스터디장이 아직 지정되지 않은 스터디도 목록에 그대로 노출한다.
    return study.leader.name if study.leader else LEADER_UNASSIGNED


class ParticipationSerializer(serializers.ModelSerializer):
    member_name = serializers.CharField(source="member.name", read_only=True)
    # 동명이인을 구분할 수 있게 학번 뒷 2자리만 함께 노출한다.
    # 학번 전체는 로그인 ID이므로 공개 API로 내보내지 않는다.
    student_id_tail = serializers.SerializerMethodField()

    def get_student_id_tail(self, obj):
        return obj.member.student_id[-2:]

    class Meta:
        model = Participation
        fields = ("id", "member_name", "student_id_tail", "status")


class MyStudySerializer(serializers.ModelSerializer):
    """마이페이지에서 쓰는, 로그인 회원 본인의 스터디 참여 이력."""

    study_id = serializers.IntegerField(source="study.id", read_only=True)
    title = serializers.CharField(source="study.title", read_only=True)
    semester = serializers.CharField(source="study.semester.name", read_only=True)
    status_label = serializers.CharField(source="get_status_display", read_only=True)

    class Meta:
        model = Participation
        fields = ("id", "study_id", "title", "semester", "status", "status_label")


class StudySerializer(serializers.ModelSerializer):
    leader_name = serializers.SerializerMethodField()
    participations = ParticipationSerializer(many=True, read_only=True)

    def get_leader_name(self, obj):
        return leader_name(obj)

    class Meta:
        model = Study
        fields = (
            "id",
            "title",
            "leader_name",
            "description",
            "prerequisites",
            "recommended",
            "participations",
        )


class SemesterSerializer(serializers.ModelSerializer):
    studies = StudySerializer(many=True, read_only=True)

    class Meta:
        model = Semester
        fields = ("id", "name", "studies")


# ── 참여자 본인용 스터디 상세 ─────────────────────────────────────


class MySubmissionSerializer(serializers.ModelSerializer):
    is_late = serializers.BooleanField(read_only=True)

    class Meta:
        model = AssignmentSubmission
        fields = ("id", "original_name", "size", "submitted_at", "is_late", "review_status", "feedback", "reviewed_at")


class MySessionSerializer(serializers.ModelSerializer):
    # 스터디장이 남긴 출석 메모는 내부 기록이라 본인에게도 보여주지 않는다.
    attendance = serializers.SerializerMethodField()

    def get_attendance(self, session):
        return self.context["attendance"].get(session.pk)

    class Meta:
        model = StudySession
        fields = ("id", "number", "title", "held_on", "attendance")


class MyAssignmentSerializer(serializers.ModelSerializer):
    is_closed = serializers.SerializerMethodField()
    submission = serializers.SerializerMethodField()

    def get_is_closed(self, assignment):
        return assignment.due_at <= timezone.now()

    def get_submission(self, assignment):
        submission = self.context["submissions"].get(assignment.pk)
        return MySubmissionSerializer(submission).data if submission else None

    class Meta:
        model = Assignment
        fields = ("id", "title", "description", "due_at", "is_closed", "submission")
