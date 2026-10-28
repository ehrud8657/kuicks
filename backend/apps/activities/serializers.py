from django.urls import reverse
from rest_framework import serializers

from .models import Activity, ActivityMember, Material, MaterialFile
from .permissions import can_contribute, can_edit_material


class MaterialFileSerializer(serializers.ModelSerializer):
    """게시판 첨부와 같은 모양으로 내려, 화면이 같은 위젯으로 그리게 한다."""

    name = serializers.CharField(source="original_name", read_only=True)
    is_image = serializers.BooleanField(read_only=True)
    url = serializers.SerializerMethodField()

    def get_url(self, attachment):
        # /media/로 공개하지 않고 이 API로만 내보낸다(사진이 아니면 항상 내려받기).
        path = reverse("activity-file", args=[attachment.pk])
        request = self.context.get("request")
        return request.build_absolute_uri(path) if request else path

    class Meta:
        model = MaterialFile
        fields = ("id", "name", "size", "content_type", "is_image", "url")


class MaterialSerializer(serializers.ModelSerializer):
    """자료. 상세 응답에 쓰이고, 자료 작성·수정 API의 입력도 받는다."""

    author_name = serializers.SerializerMethodField()
    files = MaterialFileSerializer(many=True, read_only=True)
    can_edit = serializers.SerializerMethodField()

    def get_author_name(self, material):
        return material.author_name or "알 수 없음"

    def get_can_edit(self, material):
        request = self.context.get("request")
        return bool(request) and can_edit_material(request.user, material)

    def validate_title(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError("제목을 입력해주세요.")
        return value

    class Meta:
        model = Material
        fields = (
            "id", "stage", "title", "description", "date",
            "author_name", "created_at", "updated_at", "files", "can_edit",
        )
        # 날짜는 올린 날로 자동으로 들어간다. 지난 기록을 소급할 때는 Admin에서 고친다.
        read_only_fields = ("date", "created_at", "updated_at")


class ActivityMemberSerializer(serializers.ModelSerializer):
    # 공개 응답이므로 학번은 내려보내지 않는다.
    class Meta:
        model = ActivityMember
        fields = ("name", "role")


class ActivityListSerializer(serializers.ModelSerializer):
    semester = serializers.CharField(source="semester.name")
    tags = serializers.SlugRelatedField(slug_field="name", many=True, read_only=True)
    members = ActivityMemberSerializer(many=True, read_only=True)
    material_count = serializers.SerializerMethodField()
    stages = serializers.SerializerMethodField()

    # 아래 두 값은 prefetch된 materials로 계산해 활동마다 쿼리가 늘지 않게 한다.
    def get_material_count(self, activity):
        return len(activity.materials.all())

    def get_stages(self, activity):
        """자료가 있는 단계. 목록에서 '중간 ✓ 최종 –'처럼 진행 정도를 보여주는 데 쓴다."""
        present = {material.stage for material in activity.materials.all()}
        return [stage for stage in Material.Stage.values if stage in present]

    class Meta:
        model = Activity
        fields = (
            "id", "kind", "semester", "title", "topic", "summary", "status",
            "start_date", "end_date", "result", "tags", "members", "material_count", "stages",
        )


class ActivityDetailSerializer(ActivityListSerializer):
    materials = MaterialSerializer(many=True, read_only=True)
    can_contribute = serializers.SerializerMethodField()

    def get_can_contribute(self, activity):
        request = self.context.get("request")
        return bool(request) and can_contribute(request.user, activity)

    class Meta(ActivityListSerializer.Meta):
        fields = ActivityListSerializer.Meta.fields + (
            "description", "team_name", "location", "materials", "can_contribute",
        )
