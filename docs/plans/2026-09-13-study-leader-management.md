# 스터디장 관리 기능 개발 계획 (2026-09-13)

> **진행 결과(2026-09-14)**: 1~7 분기점 완료. 개발 내용은 [개발 보고서](../reports/2026-09-14-study-leader-management-report.html), 결정이 필요한 사항은 [확인이 필요한 사항](../reports/2026-09-14-questions.html)을 참고하세요. 계획과 달라진 점: 출석 현황표 API(`GET /manage/studies/{id}/attendance/`)와 `/me/studies/`의 과제 수 필드를 추가했고, ApiClient 주입은 InheritedWidget 대신 `ApiClient.instance` 교체 방식으로 했습니다.

작성 배경: 공동작업자(김태호, `dev_tweho` 브랜치) 투입. 전임자는 휴식 중이며 당분간 단독 개발.
이 문서는 개발 착수 전 기획 단계에서 작성한 계획이며, 개발 중 결정이 바뀌면 이 문서와 `docs/API.md`를 함께 갱신한다.

## 0. 확정된 전제

| 항목 | 내용 |
|---|---|
| 배포 | 현재 Render(백엔드) + Vercel(프론트) 사용 중. 최종 목표는 동아리 전용 서버 컴퓨터(`docker-compose.prod.yml`). 저장소에서 세팅을 마치고 URL만 교체하는 방식. |
| 과제 제출 | **zip 파일만** 받는다. 링크 제출은 받지 않는다. |
| 참여자 등록 | 운영진이 `/admin`에서 스터디 참여자(Participation)를 넣는다. 스터디장 화면은 그 명단을 그대로 사용한다. |
| 스터디장 판별 | `Study.leader` 지정 시 자동으로 `role=leader`가 되는 기존 동작을 그대로 사용한다. |
| 권한 | 스터디장은 **본인 담당 스터디만**, 운영진은 **전체 스터디**를 관리한다. |
| 비밀번호 | 서버 측 비밀번호 변경 강제도 이번 작업에 포함한다. |
| 브랜치 | `dev_tweho`에 `feat:`/`fix:`/`docs:` 커밋으로 분기점마다 push. push 후 반드시 방금 만든 부분을 검토·디버깅한다. |
| 보고서 | 분기점마다 `docs/reports/*.html`로 진행 보고서를 작성한다. 확인이 필요한 사항도 같은 폴더에 HTML로 남기고, 임시 결정으로 처리한 뒤 작업을 계속한다. |

## 1. 기능 범위

### 1-1. 스터디장 관리 화면 (leader / admin)
- 로그인한 회원이 `leader` 또는 `admin`이면 상단 메뉴에 **"스터디 관리"** 항목이 추가되고, My Page 버튼에 역할 배지(스터디장/운영진)가 표시된다. → UI가 달라 보이는 요구사항.
- 스터디 목록: 내가 담당하는 스터디(운영진은 전체). 학기, 참여자 수, 회차 수, 과제 수 표시.
- 스터디 상세 (탭 3개)
  1. **참여자**: 이름, 학번, 참여 상태(수강 중/수료/우수 수료/중도 포기 — 기존 PATCH API로 변경 가능), 출석 요약(출석/지각/결석/공결 횟수), 과제 제출 수.
  2. **출석**: 회차 목록(추가/수정/삭제). 회차를 열면 참여자별로 출석/지각/결석/공결 선택 + 메모, 한 번에 저장.
  3. **과제**: 과제 목록(추가/수정/삭제: 제목, 설명, 제출 기한). 과제를 열면 참여자 전원의 제출 현황 표: 제출자·제출 시각·파일 다운로드·**지각 여부**·**미제출**, 확인 여부 토글, 간단한 피드백 작성. 필터: 전체/미제출/지각.

### 1-2. 참여자(회원) 화면
- 마이페이지 "수강 중인 스터디" 항목을 누르면 **스터디 상세**로 이동.
- 스터디 상세: 회차별 내 출석 상태, 과제 목록(기한, 내 제출 상태: 미제출/제출됨/지각 제출/확인됨, 피드백), **zip 업로드** 버튼. 재제출 허용(기존 파일 교체, 확인 상태 초기화).
- 제출은 `active`(수강 중) 참여자만 가능. 수료/중도 포기 상태는 열람만.

### 1-3. 서버 측 비밀번호 변경 강제
- `must_change_password=True`인 로그인 사용자는 `/api/auth/change-password/`, `/api/auth/logout/`, `/api/auth/csrf/`, `/api/me/`(본인 상태 확인용, GET만)를 제외한 **모든 `/api/*`에 403** `{"code": "password_change_required"}`.
- `/admin/*`도 로그인/로그아웃 페이지를 제외하고 차단하고 "홈페이지에서 먼저 비밀번호를 변경하세요" 안내를 띄운다.
- `createsuperuser`로 만든 계정은 본인이 비밀번호를 정했으므로 `must_change_password=False`로 생성한다(현재는 True라서 차단 도입 시 운영진이 Admin에서 잠기는 문제 방지).
- 프론트: 어떤 API든 `password_change_required`를 받으면 강제 변경 다이얼로그를 띄운다.

### 1-4. 함께 고치는 기존 문제
- `PATCH /studies/{studyId}/participations/{id}/`가 `studyId`를 무시하는 문제 → 스터디로 필터.
- 게시판 제목이 필터와 무관하게 "공지사항"으로 고정된 문제.
- `dart format` 미적용 파일 5개 → 파일 분리 커밋에서 함께 정리.

### 1-5. 범위 밖 (이번에 하지 않음)
- URL 라우팅(새로고침 시 홈으로 돌아가는 문제) — 별도 작업.
- 게시글 작성 화면(Admin 유지), Activity/행사 기능, DMOJ 연동.

## 2. 데이터 모델 (`apps/studies`)

기존 `AssignmentSubmit`(파일 URL만 있는 골격, 코드에서 미사용)은 **삭제**하고 아래로 대체한다. 이미 공유된 마이그레이션은 건드리지 않고 `0003`을 새로 만든다.

```
StudySession        회차
  study        FK Study (related_name="sessions")
  number       양의 정수 (회차 번호, 생략 시 자동으로 max+1)
  title        문자열 100, 비워도 됨
  held_at      날짜
  created_at
  unique (study, number)   ordering ("number",)

Attendance          출석
  session      FK StudySession (related_name="attendances")
  participation FK Participation (related_name="attendances")   ← 스터디 명단에 있는 사람만
  status       present 출석 / late 지각 / absent 결석 / excused 공결
  note         문자열 200, 비워도 됨
  updated_at
  unique (session, participation)

Assignment          과제
  study        FK Study (related_name="assignments")
  title        문자열 150
  description  텍스트, 비워도 됨
  due_at       일시
  created_by   FK Member (null, SET_NULL)
  created_at, updated_at
  ordering ("-due_at",)

AssignmentSubmission  제출
  assignment   FK Assignment (related_name="submissions")
  participation FK Participation (related_name="submissions")
  file         FileField  upload_to = submissions/<study_id>/<assignment_id>/<student_id>_<uuid8>.zip
  original_name 문자열 255
  size         정수(바이트)
  submitted_at 일시 (재제출 시 갱신)
  review_status pending 미확인 / checked 확인
  feedback     텍스트, 비워도 됨
  reviewed_at  일시 null, reviewed_by FK Member null
  unique (assignment, participation)
  is_late (property) = submitted_at > assignment.due_at
```

zip 검증: 확장자 `.zip` + 시그니처 `PK\x03\x04`(또는 빈 zip `PK\x05\x06`) + 크기 ≤ 50MB(`SUBMISSION_MAX_BYTES` 설정값). 재제출 시 이전 파일은 삭제.

파일 공개 범위: `/media/`를 정적으로 열지 않는다(제출물은 비공개). 다운로드는 **권한 검사를 거치는 API**(`FileResponse`)로만 제공한다. 그래서 운영 모드에서 Django가 media를 서빙하지 않는 현재 구조를 바꿀 필요가 없다.

Admin: 새 모델 4개 등록(회차·과제는 Study 인라인, 출석·제출은 목록 필터).

## 3. API 계약 (기본 경로 `/api`)

인증 표기: 회원 = 로그인, 담당 = 해당 스터디의 스터디장 또는 운영진.

### 회원용
| Method | Path | 인증 | 설명 |
|---|---|---|---|
| GET | `/me/studies/` | 회원 | (기존) 참여 이력 |
| GET | `/me/studies/{study_id}/` | 회원(참여자) | 스터디 상세: 회차별 내 출석, 과제 목록 + 내 제출 상태 |
| POST | `/assignments/{id}/submissions/` | 회원(active 참여자) | multipart `file`(zip). 생성 또는 재제출 |
| GET | `/submissions/{id}/download/` | 제출자 본인·담당 | 파일 다운로드 |

### 스터디장/운영진용 (`/manage/`)
| Method | Path | 설명 |
|---|---|---|
| GET | `/manage/studies/` | 담당 스터디 목록 (운영진은 전체). leader/admin 외 403 |
| GET | `/manage/studies/{id}/` | 참여자(출석 요약·제출 수 포함), 회차, 과제 요약 |
| POST | `/manage/studies/{id}/sessions/` | 회차 추가 `{number?, title, held_at}` |
| PATCH/DELETE | `/manage/sessions/{id}/` | 회차 수정/삭제 |
| GET | `/manage/sessions/{id}/attendance/` | 참여자별 출석 (`status`는 미기록이면 null) |
| PUT | `/manage/sessions/{id}/attendance/` | `{"records": [{participation_id, status, note}]}` 일괄 저장(upsert) |
| POST | `/manage/studies/{id}/assignments/` | 과제 추가 `{title, description, due_at}` |
| PATCH/DELETE | `/manage/assignments/{id}/` | 과제 수정/삭제 |
| GET | `/manage/assignments/{id}/submissions/` | 참여자 전원 행: 제출물 또는 null(미제출), `is_late` |
| PATCH | `/manage/submissions/{id}/` | `{review_status, feedback}` |
| PATCH | `/studies/{studyId}/participations/{id}/` | (기존) 참여 상태 변경 — studyId 필터 추가 |

오류 형식은 기존 초안 `{"code", "message", "fields"}`로 통일한다. 권한 없는 접근은 403(존재 여부를 숨길 필요가 없는 내부 서비스이므로 404 대신 403).

## 4. 프론트엔드 구조

단독 개발이므로 `main.dart`(1,923줄)를 먼저 분리한다. 이후 기능은 새 파일에 추가한다.

```
lib/
  main.dart               앱·테마·ApiScope(InheritedWidget으로 ApiClient 주입 → 테스트에서 MockClient 사용)
  theme.dart              색상 상수
  app_shell.dart          상단바·드로어·세션 복원·로그인/로그아웃 (기존 SiteShell)
  api_client.dart         (기존 + 새 API 메서드, 오류 code 파싱)
  models.dart             (기존 + StudySession/Attendance/Assignment/Submission 모델)
  widgets/common.dart     PageFrame, PageHeader, LoadError, EmptyState, Loading
  widgets/linkified_text.dart
  pages/home_page.dart, study_page.dart, board_page.dart, about_page.dart,
        contact_page.dart, my_page.dart, placeholder_page.dart, auth_dialogs.dart
  pages/manage/manage_page.dart        담당 스터디 목록
  pages/manage/study_manage_page.dart  탭: 참여자 / 출석 / 과제
  pages/manage/attendance_editor.dart  회차별 출석 편집
  pages/manage/submissions_page.dart   과제별 제출 현황·확인·피드백
  pages/my_study_page.dart             회원용 스터디 상세 + zip 제출
```

- 상세 화면은 `Navigator.push`로 열고 자체 AppBar(뒤로가기)를 가진다. 상단 메뉴 enum에는 `manage`만 추가한다.
- 날짜/시간 입력은 `showDatePicker`/`showTimePicker` + `flutter_localizations`(한국어 로케일, SDK 내장이라 외부 의존성 없음).
- zip 선택은 `file_picker`(pub에서 ^12.3.0 해석 확인 완료, 웹 지원). `pubspec.yaml`과 `pubspec.lock`을 함께 커밋한다.
- 한글 입력 주의: 입력 중 `setState`로 TextField를 재생성하지 않는다(컨트롤러는 State에 한 번만 생성), `maxLength` 카운터를 쓰지 않고 제출 시 검증한다. Flutter web에서 한글 IME 조합이 끊기는 원인이기 때문.
- 로딩·빈 결과·오류 상태를 모든 목록에 둔다(기존 규칙).

## 5. 배포·인프라에서 같이 손봐야 하는 것

- `frontend/nginx.conf`: `client_max_body_size 50m;` 추가 (기본 1MB라 zip 업로드가 413으로 막힘).
- `docker-compose.prod.yml`: `media_data` 볼륨이 이미 있어 업로드 파일이 유지된다. 개발용 `docker-compose.yml`은 `./backend` 마운트라 `backend/media/`에 저장됨(`.gitignore`에 `media/` 있음).
- **Render 무료 플랜은 디스크가 재배포 시 초기화**되므로 Render 운영 중 업로드된 zip은 사라질 수 있다. 전용 서버 이전 전까지는 임시 상태로 간주하고 보고서에 명시한다.
- Vercel rewrites 경유 업로드의 본문 크기 제한은 확인 필요 → 보고서에 남긴다.
- `.env.example`/`.env.prod.example`에 `SUBMISSION_MAX_BYTES` 설명 추가.

## 6. 커밋·검증 분기점

각 분기점마다: 커밋 → `git push origin dev_tweho` → 직후 방금 만든 코드 검토 → 문제는 `fix:` 커밋.

| # | 커밋 | 검증 |
|---|---|---|
| 1 | `refactor: main.dart를 화면별 파일로 분리하고 포맷 정리` | `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test`, `flutter build web` |
| 2 | `feat: 비밀번호 변경 전 API·Admin 접근을 서버에서 차단` | Django 테스트(차단/허용 경로, superuser 생성값), 프론트 강제 다이얼로그 |
| 3 | `feat: 회차·출석·과제·제출 모델과 스터디장 관리 API` | `makemigrations --check`, 권한 테스트(비로그인/일반회원/담당·비담당 스터디장/운영진), zip 검증, 지각 판정, 일괄 출석, 재제출 |
| 4 | `feat: 스터디장 관리 화면 (참여자·출석·과제 취합)` | MockClient 위젯 테스트(400px·1280px 폭에서 overflow 예외 없음), `flutter build web` |
| 5 | `feat: 마이페이지 스터디 상세와 zip 과제 제출` | 위젯 테스트, 로컬 Django 서버에 실제 업로드 curl 스모크 테스트 |
| 6 | `fix:` 검토에서 나온 수정 | 전체 재검증 |
| 7 | `docs: API 문서·보고서` | — |

로컬 검증 환경: Python 3.13 가상환경(`py -3.13 -m venv`; 기본 3.14는 Django 5.1 미지원) + SQLite, Flutter 3.44.8. Docker는 이 PC에 없어 Docker 스택은 실행하지 못한다(보고서에 명시).

## 7. 임시 결정 사항 (확인 요청 대상)

| 항목 | 임시 결정 | 이유 |
|---|---|---|
| `/api/me/` 차단 여부 | 비밀번호 미변경 상태에서도 GET `/me/`는 허용 | 프론트가 세션 복원 시 "변경 필요" 상태를 알아야 강제 다이얼로그를 띄울 수 있음. 반환 값은 본인 학번·이름·역할뿐이라 위험 낮음 |
| 재제출 | 기한과 무관하게 허용, 기존 파일 교체, 확인 상태는 미확인으로 초기화 | 스터디장이 최종본만 보면 되므로 |
| 제출 가능 상태 | `active` 참여자만 | 수료·포기자는 제출 대상 아님 |
| 제출 크기 | 50MB | 환경변수로 조정 가능 |
| 운영진 명단 중복(신채민이 교육부·총무부 모두 포함) | 그대로 둠 | 의도 여부 확인 필요 |
| Render 업로드 파일 휘발 | 임시 상태로 운영, 전용 서버에서 볼륨 사용 | 무료 플랜 제약 |

## 8. 참고: CSV `회원상태`와 운영진 권한

`python manage.py import_members members.csv`의 `회원상태` 열은 `정회원`/`휴회원`/`스터디장`/`운영진`을 받는다.
`Member.save()`가 `role == admin`일 때 `is_staff`와 `is_superuser`를 **항상 True**로 맞추므로,
CSV에 `운영진`이라고 적힌 회원은 생성 즉시 Django **슈퍼유저**(Admin 전체 권한, 회원 삭제·비밀번호 재설정 가능)가 된다.
초기 비밀번호가 `kuics!학번`으로 고정되어 있어 명단이 유출되면 운영진 계정으로 바로 들어갈 수 있으므로,
운영진 명단은 CSV로 넣지 말고 Admin에서 개별 지정하거나, 넣더라도 곧바로 로그인해 비밀번호를 바꾸게 해야 한다.
이번에 추가하는 서버 측 강제 차단(1-3)이 이 위험을 줄인다.
