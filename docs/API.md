# API 초안

기본 경로: `/api`

| Method | Path | 인증 | 설명 |
|---|---|---|---|
| GET | `/semesters/` | 공개 | 학기와 하위 스터디/참여자 목록 |
| GET | `/semesters/{id}/studies/` | 공개 | 특정 학기의 스터디 목록 |
| GET | `/studies/{id}/` | 공개 | 스터디 상세 |
| PATCH | `/studies/{studyId}/participations/{id}/` | 스터디장/운영진 | 참여 상태 변경 |
| GET | `/boards/` | 공개 | 공지 및 모집 목록 (`?category=notice`) |
| GET | `/boards/{id}/` | 공개 | 게시글 상세 |
| GET | `/auth/csrf/` | 공개 | CSRF 토큰 발급 (상태 변경 요청 전에 호출) |
| POST | `/auth/login/` | 공개 | 세션 로그인 |
| POST | `/auth/logout/` | 회원 | 로그아웃 |
| POST | `/auth/change-password/` | 회원 | 비밀번호 변경 |
| GET | `/me/` | 회원 | 로그인 회원 정보 |
| GET | `/me/studies/` | 회원 | 본인의 스터디 참여 이력 (마이페이지) |

## 스터디 응답

`/semesters/` 계열 응답은 로그인 없이 열람할 수 있으므로 **학번 전체를 내려보내지 않습니다.**
수료자 명단은 동명이인 구분을 위해 이름과 학번 뒷 2자리만 포함합니다.

```json
{
  "id": 1,
  "name": "2026-1",
  "studies": [
    {
      "id": 3,
      "title": "웹해킹 입문",
      "leader_name": "홍길동",
      "description": "...",
      "prerequisites": "없음",
      "recommended": "없음",
      "participations": [
        {"id": 7, "member_name": "김철수", "student_id_tail": "44", "status": "completed"}
      ]
    }
  ]
}
```

- `leader_name`: 스터디장이 지정되지 않은 스터디는 `"미정"`으로 내려옵니다.
- `status`: `active`(수강 중) · `completed`(수료) · `excellent`(우수 수료) · `withdrawn`(중도 포기)

`/me/studies/`는 로그인 회원 본인의 참여 이력만 반환합니다.

```json
[
  {"id": 7, "study_id": 3, "title": "웹해킹 입문", "semester": "2026-1", "status": "excellent", "status_label": "우수 수료"}
]
```

마이페이지는 `active`를 '수강 중인 스터디', `completed`/`excellent`를 '완료한 스터디'로 묶어 보여주며
`withdrawn`은 표시하지 않습니다.

스터디장은 `Study.leader` 지정만으로 결정되며, 지정 시 해당 회원의 등급이 자동으로 스터디장으로 올라갑니다.
담당 스터디가 하나도 남지 않으면 정회원으로 되돌아갑니다. (운영진은 등급이 유지됩니다.)

로그인 요청:

```json
{"student_id": "2026123456", "password": "temporary-password"}
```

권한 오류 등은 다음 구조를 기준으로 통일할 예정입니다.

```json
{"code": "permission_denied", "message": "수정 권한이 없습니다.", "fields": null}
```

