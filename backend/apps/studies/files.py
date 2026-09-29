import mimetypes
import re
from pathlib import Path

from django.conf import settings
from rest_framework.exceptions import ValidationError

# 브라우저에서 바로 띄워도 안전한 사진 형식. SVG는 스크립트를 품을 수 있어
# 같은 도메인에서 그대로 열면 위험하므로 사진으로 취급하지 않고 내려받게 한다.
INLINE_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".webp"}


def format_size(num_bytes):
    """사람이 읽기 좋은 크기 표기. 예: 52428800 -> '50MB'"""
    for unit, scale in (("GB", 1024**3), ("MB", 1024**2), ("KB", 1024)):
        if num_bytes >= scale:
            value = num_bytes / scale
            return f"{value:.0f}{unit}" if value == int(value) else f"{value:.1f}{unit}"
    return f"{num_bytes}B"


def safe_suffix(filename):
    """저장 경로에 붙일 확장자. 영문·숫자로 된 짧은 확장자만 남기고 나머지는 버린다."""
    suffix = Path(filename or "").suffix.lower()
    return suffix if re.fullmatch(r"\.[a-z0-9]{1,10}", suffix) else ""


def content_type_of(filename):
    """원본 파일명으로 짐작한 형식. 모르면 application/octet-stream."""
    guessed, _ = mimetypes.guess_type(filename or "")
    return guessed or "application/octet-stream"


def is_inline_image(filename):
    return Path(filename or "").suffix.lower() in INLINE_IMAGE_EXTENSIONS


def _reject(message):
    raise ValidationError({"file": [message]})


def validate_upload(upload, *, max_bytes, missing_message="파일을 선택해주세요."):
    """형식은 가리지 않고, 비었거나 너무 큰 파일만 거른다."""
    if upload is None:
        _reject(missing_message)
    if upload.size == 0:
        _reject("빈 파일은 올릴 수 없습니다.")
    if upload.size > max_bytes:
        _reject(f"파일 크기는 {format_size(max_bytes)} 이하여야 합니다.")


def validate_submission_file(upload):
    """과제 제출 파일 검사. 형식 제한 없이 한 파일을 받는다.

    제출물은 제출자 본인과 스터디장·운영진만 내려받을 수 있고, 항상 내려받기로만
    내보내므로(브라우저에서 열지 않음) 형식을 막지 않는다.
    """
    validate_upload(upload, max_bytes=settings.SUBMISSION_MAX_BYTES, missing_message="제출할 파일을 선택해주세요.")


def validate_study_post_file(upload):
    """스터디 게시판 자료 검사. 참여자만 받을 수 있으므로 형식은 막지 않는다."""
    validate_upload(upload, max_bytes=settings.STUDY_POST_ATTACHMENT_MAX_BYTES)
