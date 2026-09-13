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

## 오류 응답

모든 API 오류는 다음 형식으로 응답합니다 (`config/exceptions.py`).

```json
{"code": "permission_denied", "message": "수정 권한이 없습니다.", "fields": null}
```

- `code`: 프론트가 분기할 때 쓰는 식별자. `not_authenticated`, `permission_denied`, `not_found`, `invalid`(입력값 오류), `invalid_credentials`, `invalid_password`, `password_change_required` 등
- `message`: 사용자에게 그대로 보여줄 수 있는 문장
- `fields`: 입력값 오류일 때만 `{"필드명": ["메시지"]}`, 그 외에는 `null`

## 초기 비밀번호 변경 강제

`must_change_password=true`인 회원(CSV·Admin으로 만든 직후, 초기 비밀번호 `kuics!학번`)은 비밀번호를 바꾸기 전까지 서버에서 다음과 같이 제한됩니다 (`apps/accounts/middleware.py`).

| 경로 | 동작 |
|---|---|
| `/api/auth/csrf/`, `/api/auth/login/`, `/api/auth/logout/`, `/api/auth/change-password/`, `/api/me/` | 허용 |
| 공개 API (`/api/semesters/`, `/api/boards/` 등) | 비로그인 사용자와 동일하게 허용 |
| 로그인이 필요한 나머지 API | `403 {"code": "password_change_required"}` |
| `/admin/` (로그아웃 제외) | 403 안내 페이지 |

- 새 비밀번호가 현재 비밀번호와 같으면 `400 invalid_password`로 거절합니다. (초기 비밀번호도 조합 규칙을 만족하기 때문)
- `createsuperuser`로 만든 계정은 본인이 비밀번호를 정했으므로 `must_change_password=false`로 생성됩니다.
- 프론트는 어떤 API에서든 `password_change_required`를 받으면 강제 변경 창을 띄웁니다.

