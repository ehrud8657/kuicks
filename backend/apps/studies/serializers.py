from rest_framework import serializers
from .models import Participation, Semester, Study

class ParticipationSerializer(serializers.ModelSerializer):
    member_name = serializers.CharField(source="member.name", read_only=True)
    class Meta:
        model = Participation
        fields = ("id", "member", "member_name", "status")
        read_only_fields = ("member",)

class StudySerializer(serializers.ModelSerializer):
    leader_name = serializers.CharField(source="leader.name", read_only=True)
    participations = ParticipationSerializer(many=True, read_only=True)
    class Meta:
        model = Study
        fields = ("id", "title", "leader", "leader_name", "description", "prerequisites", "recommended", "participations")

class SemesterSerializer(serializers.ModelSerializer):
    studies = StudySerializer(many=True, read_only=True)
    class Meta:
        model = Semester
        fields = ("id", "name", "studies")

