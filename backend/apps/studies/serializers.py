from rest_framework import serializers
from .models import Participation, Semester, Study

LEADER_UNASSIGNED = "미정"


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


class StudySerializer(serializers.ModelSerializer):
    leader_name = serializers.SerializerMethodField()
    participations = ParticipationSerializer(many=True, read_only=True)

    def get_leader_name(self, obj):
        # 스터디장이 아직 지정되지 않은 스터디도 목록에 그대로 노출한다.
        return obj.leader.name if obj.leader else LEADER_UNASSIGNED

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
