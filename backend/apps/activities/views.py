"""활동 아카이브 API (/api/activities/...).

열람은 누구나 할 수 있다. 자료 작성은 그 활동의 참여자 중 정회원 이상과 운영진만 한다
(permissions.can_contribute). 활동 자체는 운영진이 Admin에서 만든다.
"""

from django.conf import settings
from django.db.models import Prefetch
from django.http import FileResponse
from django.shortcuts import get_object_or_404
from rest_framework import generics, permissions, status
from rest_framework.exceptions import NotFound, PermissionDenied
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.studies.files import content_type_of, validate_upload
from apps.studies.models import Semester

from .models import Activity, Material, MaterialFile, Tag
from .permissions import can_contribute, can_edit_material
from .serializers import (
    ActivityDetailSerializer,
    ActivityListSerializer,
    MaterialFileSerializer,
    MaterialSerializer,
)


def published_activities():
    return Activity.objects.filter(is_published=True)


class ActivityListView(generics.ListAPIView):
    """활동 목록. ?kind=project&semester=2026-2&tag=web 로 거른다. 20개씩 페이지로 나간다."""

    serializer_class = ActivityListSerializer

    def get_queryset(self):
        queryset = published_activities().select_related("semester").prefetch_related(
            "tags", "members", Prefetch("materials", queryset=Material.objects.only("id", "activity_id", "stage"))
        )
        params = self.request.query_params
        if kind := params.get("kind"):
            queryset = queryset.filter(kind=kind)
        if semester := params.get("semester"):
            queryset = queryset.filter(semester__name=semester)
        if tag := params.get("tag"):
            queryset = queryset.filter(tags__name=tag)
        return queryset


class ActivityFilterView(APIView):
    """목록 화면의 거르기 선택지. 공개된 활동이 있는 학기와 쓰이는 태그만 준다."""

    def get(self, request):
        activities = published_activities()
        semesters = Semester.objects.filter(activities__in=activities).distinct().values_list("name", flat=True)
        tags = Tag.objects.filter(activities__in=activities).distinct().values_list("name", flat=True)
        return Response({"semesters": list(semesters), "tags": list(tags)})


def _activity_detail_queryset():
    return published_activities().select_related("semester").prefetch_related(
        "tags", "members", "materials__files"
    )


class ActivityDetailView(generics.RetrieveAPIView):
    serializer_class = ActivityDetailSerializer

    def get_queryset(self):
        return _activity_detail_queryset()


class MaterialCreateView(generics.CreateAPIView):
    """자료 글만 먼저 만든다. 파일은 자료가 생긴 뒤 한 개씩 올린다(요청 하나가 너무 커지지 않게)."""

    serializer_class = MaterialSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def perform_create(self, serializer):
        activity = get_object_or_404(_activity_detail_queryset(), pk=self.kwargs["activity_id"])
        if not can_contribute(self.request.user, activity):
            raise PermissionDenied("이 활동의 참여자(정회원 이상)와 운영진만 자료를 올릴 수 있습니다.")
        serializer.save(activity=activity, author=self.request.user)


def _material_for_edit(request, pk):
    material = get_object_or_404(
        Material.objects.filter(activity__is_published=True).select_related("activity"), pk=pk
    )
    if not can_edit_material(request.user, material):
        raise PermissionDenied("올린 본인과 운영진만 고칠 수 있습니다.")
    return material


class MaterialDetailView(generics.UpdateAPIView, generics.DestroyAPIView):
    serializer_class = MaterialSerializer
    permission_classes = (permissions.IsAuthenticated,)
    http_method_names = ("patch", "delete", "options")

    def get_object(self):
        return _material_for_edit(self.request, self.kwargs["pk"])


class MaterialFileCreateView(APIView):
    """자료 하나에 파일 하나를 붙인다. 형식은 가리지 않는다."""

    permission_classes = (permissions.IsAuthenticated,)
    parser_classes = (MultiPartParser, FormParser)

    def post(self, request, pk):
        material = _material_for_edit(request, pk)
        upload = request.FILES.get("file")
        validate_upload(upload, max_bytes=settings.ACTIVITY_FILE_MAX_BYTES)
        name = upload.name[-255:]
        attachment = MaterialFile.objects.create(
            material=material,
            file=upload,
            original_name=name,
            content_type=content_type_of(name)[:120],
            size=upload.size,
        )
        # 첨부가 바뀌면 자료도 수정된 것으로 본다.
        material.save(update_fields=["updated_at"])
        return Response(
            MaterialFileSerializer(attachment, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )


class MaterialFileView(APIView):
    """자료 첨부 내려받기(누구나)와 삭제(올린 본인·운영진).

    사진(jpg·png·gif·webp)은 화면에 바로 띄워야 하므로 기본이 inline이고, ?download=1이면 내려받기가 된다.
    나머지 형식(SVG·HTML 포함)은 같은 도메인에서 열리지 않도록 항상 내려받기로만 내보낸다.
    """

    def get_permissions(self):
        if self.request.method == "DELETE":
            return [permissions.IsAuthenticated()]
        return super().get_permissions()

    def _get_file(self, pk):
        return get_object_or_404(
            MaterialFile.objects.filter(material__activity__is_published=True).select_related("material__activity"),
            pk=pk,
        )

    def get(self, request, pk):
        attachment = self._get_file(pk)
        try:
            handle = attachment.file.storage.open(attachment.file.name, "rb")
        except FileNotFoundError as exc:
            raise NotFound("파일을 찾을 수 없습니다. 서버 저장소가 초기화되었을 수 있습니다.") from exc
        inline = attachment.is_image and request.query_params.get("download") != "1"
        return FileResponse(
            handle,
            as_attachment=not inline,
            filename=attachment.original_name,
            content_type=attachment.content_type if inline else "application/octet-stream",
        )

    def delete(self, request, pk):
        attachment = self._get_file(pk)
        material = _material_for_edit(request, attachment.material_id)
        attachment.delete()
        material.save(update_fields=["updated_at"])
        return Response(status=status.HTTP_204_NO_CONTENT)
