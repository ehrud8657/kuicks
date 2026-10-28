from apps.accounts.models import Member

# 자료를 올릴 수 있는 등급. 휴회원은 제외한다.
CONTRIBUTOR_ROLES = (Member.Role.MEMBER, Member.Role.LEADER, Member.Role.ADMIN)


def is_admin(user):
    return user.is_authenticated and user.role == Member.Role.ADMIN


def can_contribute(user, activity):
    """자료를 올릴 수 있는지. 운영진은 모든 활동, 정회원 이상은 본인이 참여한 활동에만 올린다.

    보관된 활동은 기록을 지키기 위해 운영진만 손댈 수 있다.
    """
    if not user.is_authenticated or user.role not in CONTRIBUTOR_ROLES:
        return False
    if is_admin(user):
        return True
    if activity.status == activity.Status.ARCHIVED:
        return False
    # filter() 대신 all()을 훑어, 상세 응답처럼 참여자를 미리 불러온 경우 쿼리를 다시 하지 않는다.
    return any(entry.member_id == user.pk for entry in activity.members.all())


def can_edit_material(user, material):
    """자료 수정·삭제. 운영진, 또는 지금도 올릴 자격이 있는 본인."""
    if is_admin(user):
        return True
    return material.author_id == user.pk and can_contribute(user, material.activity)
