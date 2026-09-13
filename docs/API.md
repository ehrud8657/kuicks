# API

기본 경로: `/api`

인증 표기: **공개** = 누구나 · **회원** = 로그인 · **참여자** = 해당 스터디 참여 기록이 있는 회원 · **담당** = 해당 스터디의 스터디장 또는 운영진 · **관리자** = 담당 스터디가 하나라도 있는 스터디장 또는 운영진

## 공개·회원

| Method | Path | 인증 | 설명 |
|---|---|---|---|
| GET | `/semesters/` | 공개 | 학기와 하위 스터디/참여자 목록 |
| GET | `/semesters/{id}/studies/` | 공개 | 특정 학기의 스터디 목록 |
| GET | `/studies/{id}/` | 공개 | 스터디 상세 |
| PATCH | `/studies/{studyId}/participations/{id}/` | 담당 | 참여 상태 변경 `{"status": "completed"}` (URL의 스터디에 속한 참여 기록만) |
| GET | `/boards/` | 공개 | 공지 및 모집 목록 (`?category=notice`, `?page=2`, 20개 단위) |
| GET | `/boards/{id}/` | 공개 | 게시글 상세 |
| GET | `/auth/csrf/` | 공개 | CSRF 토큰 발급 (상태 변경 요청 전에 호출) |
| POST | `/auth/login/` | 공개 | 세션 로그인 |
| POST | `/auth/logout/` | 회원 | 로그아웃 |
| POST | `/auth/change-password/` | 회원 | 비밀번호 변경 |
| GET | `/me/` | 회원 | 로그인 회원 정보 |
| GET | `/me/studies/` | 회원 | 본인의 스터디 참여 이력 (마이페이지) |
| GET | `/me/studies/{studyId}/` | 참여자 | 본인 기준 스터디 상세: 회차별 내 출석, 과제와 내 제출 상태 |
| POST | `/assignments/{id}/submissions/` | 참여자(수강 중) | zip 과제 제출 (multipart `file`). 이미 냈으면 교체 |
| GET | `/submissions/{id}/download/` | 제출자 본인·담당 | 제출 파일 내려받기 |

## 스터디 관리 (스터디장·운영진)

스터디장은 **본인이 담당하는 스터디만**, 운영진은 **모든 스터디**를 관리합니다. 스터디장 판단은 등급(`role`)이 아니라 실제 `Study.leader` 지정 여부로 합니다.

| Method | Path | 인증 | 설명 |
|---|---|---|---|
| GET | `/manage/studies/` | 관리자 | 관리할 수 있는 스터디 목록 |
| GET | `/manage/studies/{id}/` | 담당 | 참여자(출석 요약·제출 수)·회차·과제 요약 |
| POST | `/manage/studies/{id}/sessions/` | 담당 | 회차 추가 `{"number"?, "title", "held_on"}` — `number`를 비우면 마지막 회차 + 1 |
| GET/PATCH/DELETE | `/manage/sessions/{id}/` | 담당 | 회차 조회·수정·삭제 (삭제 시 출석 기록도 삭제) |
| GET | `/manage/sessions/{id}/attendance/` | 담당 | 회차 출석부 |
| PUT | `/manage/sessions/{id}/attendance/` | 담당 | 출석 일괄 저장 |
| POST | `/manage/studies/{id}/assignments/` | 담당 | 과제 등록 `{"title", "description", "due_at"}` |
| GET/PATCH/DELETE | `/manage/assignments/{id}/` | 담당 | 과제 조회·수정·삭제 (삭제 시 제출 파일도 삭제) |
| GET | `/manage/assignments/{id}/submissions/` | 담당 | 과제 제출 현황 (참여자 전원, 미제출은 `submission: null`) |
| PATCH | `/manage/submissions/{id}/` | 담당 | 확인 여부·피드백 `{"review_status": "checked", "feedback": "..."}` |

### 스터디 관리 목록 `GET /manage/studies/`

```json
[
  {
    "id": 3, "title": "웹해킹 입문", "semester": "2026-2", "leader_name": "김스터디장",
    "participant_count": 12, "session_count": 4, "assignment_count": 2, "unchecked_count": 5
  }
]
```

- `participant_count`: 중도 포기자 제외
- `unchecked_count`: 아직 확인하지 않은 제출물 수

### 스터디 관리 상세 `GET /manage/studies/{id}/`

```json
{
  "id": 3, "title": "웹해킹 입문", "semester": "2026-2", "leader_name": "김스터디장", "description": "...",
  "participants": [
    {
      "id": 7, "member_name": "홍길동", "student_id": "2026320044", "status": "active", "status_label": "수강 중",
      "attendance": {"present": 3, "late": 1, "absent": 0, "excused": 0},
      "submitted_count": 2
    }
  ],
  "sessions": [{"id": 1, "number": 1, "title": "OT", "held_on": "2026-09-01", "recorded_count": 12}],
  "assignments": [
    {"id": 5, "title": "SQLi 실습", "description": "...", "due_at": "2026-09-20T23:59:00+09:00",
     "submitted_count": 10, "late_count": 1, "unchecked_count": 4}
  ]
}
```

관리 화면이므로 참여자 학번 전체(`student_id`)를 포함합니다. 공개 API(`/semesters/`)는 여전히 뒷 2자리만 내려갑니다.

### 출석부 `GET|PUT /manage/sessions/{id}/attendance/`

출석 상태: `present`(출석) · `late`(지각) · `absent`(결석) · `excused`(공결). 기록하지 않았으면 `null`.

```json
{
  "session": {"id": 1, "number": 1, "title": "OT", "held_on": "2026-09-01", "recorded_count": 1},
  "records": [
    {"participation_id": 7, "member_name": "홍길동", "student_id": "2026320044",
     "participation_status": "active", "status": "late", "note": "10분 지각"}
  ]
}
```

PUT 요청 본문 (응답은 GET과 같음):

```json
{"records": [{"participation_id": 7, "status": "present", "note": ""}, {"participation_id": 8, "status": null}]}
```

- `status: null`이면 해당 참여자의 기록을 지웁니다.
- 다른 스터디의 참여 기록이 섞여 있으면 `400`이며 아무것도 저장하지 않습니다.
- 중도 포기자는 기록이 있을 때만 출석부에 나옵니다.

### 과제 제출 현황 `GET /manage/assignments/{id}/submissions/`

```json
{
  "assignment": {"id": 5, "title": "SQLi 실습", "due_at": "...", "submitted_count": 1, "late_count": 1, "unchecked_count": 1},
  "rows": [
    {
      "participation_id": 7, "member_name": "홍길동", "student_id": "2026320044", "participation_status": "active",
      "submission": {
        "id": 11, "original_name": "홍길동_SQLi.zip", "size": 20480, "submitted_at": "...",
        "is_late": true, "review_status": "pending", "feedback": "", "reviewed_at": null, "reviewed_by_name": null
      }
    },
    {"participation_id": 8, "member_name": "이영희", "student_id": "2026320045", "participation_status": "active", "submission": null}
  ]
}
```

- `is_late`: 제출 시각이 기한보다 늦음
- 중도 포기자는 제출물이 있을 때만 행에 나오며, 미제출자로 세지 않습니다.

## 과제 제출 (참여자)

### 스터디 상세 `GET /me/studies/{studyId}/`

```json
{
  "study": {"id": 3, "title": "웹해킹 입문", "semester": "2026-2", "leader_name": "김스터디장", "description": "..."},
  "participation": {"id": 7, "status": "active", "status_label": "수강 중"},
  "can_submit": true,
  "sessions": [{"id": 1, "number": 1, "title": "OT", "held_on": "2026-09-01", "attendance": "late"}],
  "assignments": [
    {
      "id": 5, "title": "SQLi 실습", "description": "...", "due_at": "...", "is_closed": false,
      "submission": {"id": 11, "original_name": "홍길동_SQLi.zip", "size": 20480, "submitted_at": "...",
                     "is_late": false, "review_status": "checked", "feedback": "좋습니다", "reviewed_at": "..."}
    }
  ]
}
```

- 참여 기록이 없으면 `404`.
- 출석 메모(`note`)는 스터디장 내부 기록이라 참여자에게 보내지 않습니다.
- `can_submit`: 참여 상태가 `active`(수강 중)일 때만 `true`.

### 제출 `POST /assignments/{id}/submissions/`

- `multipart/form-data`, 필드명 `file`
- **zip만 허용**: 확장자 `.zip` + 실제 zip 구조 검사. 최대 `SUBMISSION_MAX_BYTES`(기본 50MB)
- 처음 제출하면 `201`, 다시 제출하면 기존 파일을 교체하고 `200`. 다시 제출하면 확인 상태가 `pending`으로 돌아가며 피드백은 남습니다.
- 기한이 지나도 제출할 수 있고 `is_late: true`로 표시됩니다.
- 수강 중(`active`)이 아닌 참여자·비참여자는 `403`.

### 파일 보관

- 파일은 `MEDIA_ROOT/submissions/{스터디}/{과제}/{학번}_{임의값}.zip`에 저장되며, 원본 파일명은 DB에만 둡니다.
- 제출물은 `/media/`로 공개하지 않고 `GET /submissions/{id}/download/`(권한 검사)로만 내려받습니다.
- 과제·스터디·참여 기록을 지우면 파일도 함께 지워집니다.

## 스터디 응답 (공개)

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
  {"id": 7, "study_id": 3, "title": "웹해킹 입문", "semester": "2026-1", "status": "active", "status_label": "수강 중",
   "assignment_count": 3, "pending_assignment_count": 1}
]
```

- `assignment_count`: 스터디에 등록된 과제 수
- `pending_assignment_count`: 기한이 남았는데 아직 내지 않은 과제 수. 수강 중(`active`)이 아니면 0

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

## 개발용 가상 데이터

```powershell
cd backend
python manage.py seed_demo
```

`DEBUG=true`에서만 동작하며, 학번이 `2099`로 시작하는 가상 회원과 `2099-1` 학기의 예시 스터디(회차·출석·과제·제출물)를 만듭니다. 비밀번호는 모두 `Kuics-demo-2026!`입니다.
