import zipfile
from pathlib import Path

from django.conf import settings
from rest_framework.exceptions import ValidationError


def format_size(num_bytes):
    """사람이 읽기 좋은 크기 표기. 예: 52428800 -> '50MB'"""
    for unit, scale in (("GB", 1024**3), ("MB", 1024**2), ("KB", 1024)):
        if num_bytes >= scale:
            value = num_bytes / scale
            return f"{value:.0f}{unit}" if value == int(value) else f"{value:.1f}{unit}"
    return f"{num_bytes}B"


def _reject(message):
    raise ValidationError({"file": [message]})


def validate_submission_file(upload):
    """과제 제출 파일 검사. zip만 받는다.

    확장자만 보면 이름만 바꾼 파일이 통과하므로 실제 zip 구조인지도 확인한다.
    """
    if upload is None:
        _reject("제출할 zip 파일을 선택해주세요.")
    if Path(upload.name).suffix.lower() != ".zip":
        _reject("zip 파일만 제출할 수 있습니다.")
    if upload.size == 0:
        _reject("빈 파일은 제출할 수 없습니다.")
    max_bytes = settings.SUBMISSION_MAX_BYTES
    if upload.size > max_bytes:
        _reject(f"파일 크기는 {format_size(max_bytes)} 이하여야 합니다.")
    is_zip = zipfile.is_zipfile(upload)
    upload.seek(0)
    if not is_zip:
        _reject("올바른 zip 파일이 아니거나 파일이 손상되었습니다.")
