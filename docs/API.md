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
| POST | `/auth/login/` | 공개 | 세션 로그인 |
| POST | `/auth/logout/` | 회원 | 로그아웃 |
| POST | `/auth/change-password/` | 회원 | 비밀번호 변경 |
| GET | `/me/` | 회원 | 로그인 회원 정보 |

로그인 요청:

```json
{"student_id": "2026123456", "password": "temporary-password"}
```

권한 오류 등은 다음 구조를 기준으로 통일할 예정입니다.

```json
{"code": "permission_denied", "message": "수정 권한이 없습니다.", "fields": null}
```

