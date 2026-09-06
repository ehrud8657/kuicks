import re

from django.core.exceptions import ValidationError


class CompositionPasswordValidator:
    """영문/숫자/특수문자를 모두 포함한 최소 길이의 비밀번호만 허용한다."""

    def __init__(self, min_length=10):
        self.min_length = min_length

    def validate(self, password, user=None):
        errors = []
        if len(password) < self.min_length:
            errors.append(f"비밀번호는 최소 {self.min_length}자 이상이어야 합니다.")
        if not re.search(r"[A-Za-z]", password):
            errors.append("영문자를 포함해야 합니다.")
        if not re.search(r"[0-9]", password):
            errors.append("숫자를 포함해야 합니다.")
        if not re.search(r"[^A-Za-z0-9]", password):
            errors.append("특수문자를 포함해야 합니다.")
        if errors:
            raise ValidationError(errors)

    def get_help_text(self):
        return f"영문, 숫자, 특수문자를 모두 포함한 {self.min_length}자 이상으로 입력해주세요."
