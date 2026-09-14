# 주소(URL) 라우팅 · 한글 글꼴 · 검토 질문(Q-01~Q-04) 처리 계획

작성일: 2026-09-14 / 브랜치: `dev_tweho`

## 배경

- 화면 이동이 `Navigator.push`와 셸 내부 상태로만 이뤄져 주소가 항상 `/`였다.
  - 브라우저 뒤로가기를 누르면 사이트 밖으로 나간다.
  - 새로고침하거나 주소를 공유하면 홈으로 돌아간다.
- Flutter Web(CanvasKit)은 한글 글꼴을 필요할 때 받아와, 처음 쓰는 글자가 잠깐 ☒로 보였다.
- 수동 점검 문서의 질문 Q-01~Q-04를 제안대로 처리하기로 했다.

## 결정

### 1. go_router 도입

- `usePathUrlStrategy()`로 `/#/` 없는 주소를 쓴다. nginx `try_files`와 vercel rewrites는 이미 index.html로 돌려준다.
- 상단 메뉴가 있는 화면은 `ShellRoute` 안에 둔다.
- 상세 화면은 부모 경로의 하위 경로로, 최상위 Navigator에 쌓는다. 그래서 주소로 바로 들어와도 ←가 부모로 간다.
- `GoRouter.optionURLReflectsImperativeAPIs = true`로 push한 화면도 주소와 방문 기록에 남긴다.

### 2. 경로표

| 경로 | 화면 | 조건 |
|---|---|---|
| `/` | 홈 | |
| `/about`, `/activity`, `/contact` | 소개 / 활동 / 문의 | |
| `/study?semester=2026-1` | 스터디 목록 (학기) | |
| `/board?category=notice` | 게시판 (분류) | |
| `/me` | 마이페이지 | 로그인 |
| `/me/studies/:id` | 내 스터디 상세·과제 제출 | 로그인 |
| `/manage` | 스터디 관리 목록 | 스터디장·운영진 |
| `/manage/studies/:id` | → `/manage/studies/:id/participants` | |
| `/manage/studies/:id/{participants,attendance,assignments}` | 스터디 관리 탭 | 스터디장·운영진 |
| `/manage/studies/:id/attendance/:sessionId` | 회차 출석 체크 | 스터디장·운영진 |
| `/manage/studies/:id/assignments/:assignmentId` | 과제 제출 현황 | 스터디장·운영진 |
| 그 밖 | 페이지를 찾을 수 없음 | |

### 3. 화면 동작 규칙

- 탭·학기·게시판 분류를 바꿀 때는 `replace`를 써서 방문 기록을 늘리지 않는다.
- 로그인 상태는 `AuthController`와 `AuthScope`로 앱 전체에서 공유한다. 이전에는 셸 내부 상태였다.
- 권한 안내는 `RequireLogin`과 `RequireManager`가 담당한다. 실제 권한은 서버가 계속 검사한다.
- 하위 화면에서 돌아올 때 다시 불러오는 일은 `RefreshOnReturn`이 경로 변화로 처리한다.
- 출석 체크에 저장하지 않은 변경이 있으면 `onExit`로 확인한다. ← 버튼, 브라우저 뒤로가기, 메뉴 이동 모두 해당한다.

### 4. 한글 글꼴

- Pretendard(SIL OFL) Regular·Bold·ExtraBold를 앱에 포함한다.
- 첫 로딩이 약 4.7MB 늘어나지만, 글자가 ☒로 보였다가 바뀌는 현상은 없어진다.

### 5. 질문 처리

- **Q-01**: 상세 화면의 스터디·과제 제목은 3줄까지 보이고 `…`로 줄인다.
- **Q-02**: 메뉴 서랍에서 로그인에 성공하면 서랍을 닫고 홈을 보여준다.
- **Q-04**: 로그인이 풀린 채 API를 부르는 경우를 처리한다.
  - 서버와 앱 모두 "로그인이 필요합니다. 다시 로그인해주세요."로 안내한다.
  - 앱은 로그인 상태를 비우고 로그인 창을 띄운다.

## 확인 방법

- 위젯 테스트 `test/router_test.dart`
  - 주소로 바로 들어오기와 ←
  - 탭 주소
  - 나가기 확인
  - 권한 안내
  - 404
  - 게시판 분류
  - Q-04
- 로컬 빌드 + Playwright
  - 경로마다 새로고침
  - 브라우저 뒤로/앞으로
  - 저장 안 한 출석에서 브라우저 뒤로가기
  - gstatic 글꼴 요청이 없는지
