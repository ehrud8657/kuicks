# KUICS Homepage

고려대학교 정보보호 동아리 KUICS의 신규 홈페이지 모노레포입니다. 기존 DMOJ 사이트와 분리하여 운영하며, Flutter Web 프론트엔드와 Django REST Framework 백엔드로 구성합니다.

## 구성

```text
kuics/
├─ frontend/            Flutter Web (Dockerfile: flutter build + nginx)
├─ backend/             Django + DRF
│  ├─ apps/accounts/    학번 로그인, 회원, CSV 일괄 생성
│  ├─ apps/studies/     학기, 스터디, 참여, 과제 제출 골격
│  ├─ apps/boards/      공지사항 및 모집공고
│  └─ apps/activities/  행사 및 참여 골격
├─ docs/                설계 및 API 문서
└─ docker-compose.yml   PostgreSQL + backend + frontend(nginx) 전체 스택
```

## 공동작업 안내

### 처음 참여할 때

1. 이 README의 빠른 시작으로 로컬 환경을 준비하고, [개발 가이드](./DEVELOPMENT_GUIDE.md)와 [API 문서](./docs/API.md)를 읽습니다.
2. 맡을 기능과 수정할 파일을 다른 작업자와 먼저 공유합니다. 같은 파일이나 DB 모델을 동시에 수정하게 되면 작업 범위와 순서를 조율합니다.
3. 개발에는 로컬 DB와 가상 회원 데이터를 사용합니다. 운영 계정이나 실제 회원 명단은 저장소·이슈·PR에 올리지 않습니다.

주요 수정 위치는 다음과 같습니다.

| 작업 | 위치 |
|---|---|
| 화면 및 UI | `frontend/lib/main.dart` |
| 프론트 데이터 모델 및 API 호출 | `frontend/lib/models.dart`, `frontend/lib/api_client.dart` |
| 회원·로그인·권한 | `backend/apps/accounts/` |
| 학기·스터디·참여 | `backend/apps/studies/` |
| 공지·모집 게시판 | `backend/apps/boards/` |
| 행사 | `backend/apps/activities/` |
| Django 설정 및 URL | `backend/config/` |
| API 계약 | `docs/API.md` |

### 지켜야 할 수칙

- 프론트엔드는 DB에 직접 접근하지 않고 API만 호출합니다. 인증·권한·입력 검증은 Django에서 수행하며, 버튼을 숨기는 것만으로 접근을 제한하지 않습니다.
- 역할은 `member`(회원), `leader`(스터디장), `admin`(운영진)입니다. 권한 관련 변경은 비로그인 사용자, 일반 회원, 담당/비담당 스터디장, 운영진의 접근 범위를 확인합니다.
- `AUTH_USER_MODEL`은 `accounts.Member`로 유지합니다. 모델을 바꾸면 마이그레이션을 생성해 같은 PR에 포함하고, 이미 공유·적용된 마이그레이션은 임의로 수정하거나 삭제하지 않습니다. 번호 충돌은 다른 작업자와 조율합니다.
- API 경로·필드·응답·권한을 바꾸면 백엔드와 Flutter 모델/API 클라이언트를 함께 확인하고 `docs/API.md`도 갱신합니다. UI는 로딩·빈 결과·오류 상태를 처리합니다.
- `.env`, 비밀번호, 토큰, 회원 CSV, DB 백업은 커밋하지 않습니다. `.gitignore`에 없는 이름의 민감 파일도 직접 확인합니다. 새 환경변수는 실제 비밀값 없이 `.env.example`과 필요한 경우 `.env.prod.example`에 설명을 추가합니다.
- 의존성을 바꾸면 `backend/requirements.txt` 또는 `frontend/pubspec.yaml`과 `frontend/pubspec.lock`을 함께 갱신합니다. 빌드 결과, 가상환경, 로컬 DB는 커밋하지 않습니다.
- 운영 서버의 소스를 직접 수정하지 않고 Git 이력으로 배포합니다. 운영 배포·데이터 변경은 담당자와 조율하고, DB 변경 전 백업과 복구 방법을 확인합니다. `docker compose down -v`는 DB 볼륨도 삭제하므로 운영 환경에서 실행하지 않습니다.

### 브랜치와 PR

1. 기본 브랜치의 최신 내용을 받은 뒤 `feat/study-filter`, `fix/login-error`, `docs/collaboration`처럼 작업 목적이 드러나는 브랜치를 만듭니다. 기본 브랜치에 직접 push하지 않고 PR로 합칩니다.
2. PR 하나에는 하나의 목적을 담고, 관계없는 리팩터링·포맷 변경은 분리합니다. 커밋 메시지는 `feat: 스터디 필터 추가`처럼 변경 내용을 구체적으로 적습니다.
3. PR에 변경 이유와 내용, 확인한 명령과 결과, UI 변경 시 개인정보가 없는 화면 캡처를 적습니다. API·환경변수·마이그레이션 변경과 배포 시 필요한 작업도 명시합니다.
4. 다른 공동작업자 1명 이상의 리뷰를 받고 지적 사항을 반영한 뒤 병합합니다. 공유 브랜치에 force push하거나 다른 작업자의 커밋을 임의로 되돌리지 않습니다.

### PR 제출 전 점검

저장소 루트에서 변경한 영역에 해당하는 명령을 실행합니다.

```powershell
cd backend
python manage.py check
python manage.py makemigrations --check --dry-run
python manage.py test

cd ..\frontend
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web --dart-define=API_BASE_URL=/api
```

기능 변경에는 동작과 권한을 확인하는 테스트를 추가하거나 갱신합니다. 로그인·쿠키·프록시 관련 변경은 Docker 환경에서도 로그인, 로그아웃, 권한별 접근을 직접 확인합니다. 실행하지 못한 점검은 이유와 함께 PR에 남깁니다.

## 빠른 시작

### Backend

Python 3.12 이상과 PostgreSQL을 권장합니다. `DATABASE_URL`이 없으면 로컬 SQLite를 사용합니다.

```powershell
cd backend
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver
```

API는 기본적으로 `http://localhost:8000/api`에서 제공되고 관리자 페이지는 `/admin`입니다.

### Frontend

```powershell
cd frontend
flutter pub get
flutter run -d chrome --web-port 3000 --dart-define=API_BASE_URL=http://localhost:8000/api
```

프로덕션 빌드:

```powershell
flutter build web --dart-define=API_BASE_URL=https://새도메인.example/api
```

### Docker로 전체 스택 실행 — 개발용

`docker-compose.yml`은 실제 배포와 동일하게 **프론트(nginx)와 백엔드를 같은 도메인**으로 묶는 구성입니다. nginx가 `/`는 Flutter web 빌드 결과물을, `/api`·`/admin`·`/static`·`/media`는 backend로 라우팅하므로 브라우저 입장에선 항상 하나의 origin만 봅니다 — CORS/CSRF/쿠키 설정이 단순해지는 이유입니다. 프론트는 `API_BASE_URL=/api`(상대 경로)로 빌드되어 이 구조를 그대로 전제합니다.

```powershell
Copy-Item .env.example .env
docker compose up --build
```

`http://localhost`로 접속하면 프론트와 API가 동시에 뜹니다. 첫 실행 후 별도 터미널에서 migration과 운영진 계정을 만듭니다.

```powershell
docker compose exec backend python manage.py migrate
docker compose exec backend python manage.py createsuperuser
```

실제 배포 도메인이 정해지면 `.env`의 `CORS_ALLOWED_ORIGINS`만 그 주소로 바꾸면 됩니다. 프론트/백엔드를 서로 다른 서브도메인으로 나눠야 하는 경우에만 `CROSS_SITE_COOKIES=true`를 추가로 켭니다 (자세한 내용은 [DEVELOPMENT_GUIDE.md](./DEVELOPMENT_GUIDE.md) 참고).

이 구성은 **개발용**입니다. `./backend`를 컨테이너에 그대로 붙여두기 때문에 코드를 고치면 바로 반영되고, Django 개발 서버와 `DEBUG=true`를 씁니다. 상시 켜두는 서버에는 아래 운영용 구성을 쓰세요.

### Docker로 상시 운영 — 운영용

`docker-compose.prod.yml`은 항상 켜두는 서버를 위한 구성입니다. 개발용과 이렇게 다릅니다.

| | 개발용 (`docker-compose.yml`) | 운영용 (`docker-compose.prod.yml`) |
|---|---|---|
| 웹 서버 | `manage.py runserver` | `gunicorn` (워커 3개) |
| 소스 | 호스트 폴더를 마운트 (고치면 즉시 반영) | 이미지에 포함 (호스트와 무관하게 동일 동작) |
| `DEBUG` | `true` | `false` |
| 재시작 | 없음 | `unless-stopped` (재부팅·크래시 시 자동 복구) |
| 비밀값 | 기본값 사용 | `.env`에서 주입, 없으면 실행 거부 |
| migrate | 수동 | 컨테이너 시작 시 자동 |
| 포트 | `80`, `8000` 노출 | `80`만 노출 |

먼저 환경변수를 채웁니다. `DJANGO_SECRET_KEY`와 `POSTGRES_PASSWORD`는 비워두면 컨테이너가 뜨지 않습니다.

```powershell
Copy-Item .env.prod.example .env
notepad .env
```

`DJANGO_SECRET_KEY`는 아래로 만들어 붙여넣습니다.

```powershell
docker compose -f docker-compose.prod.yml run --rm backend python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
```

접속할 도메인이나 IP가 있으면 `DJANGO_ALLOWED_HOSTS`와 `CORS_ALLOWED_ORIGINS`에 함께 적습니다. 이 값이 틀리면 사이트는 열려도 로그인이 CSRF 오류로 막힙니다.

```powershell
docker compose -f docker-compose.prod.yml up -d --build
```

첫 실행 후 운영진 계정을 만듭니다. migrate는 컨테이너가 뜰 때 이미 실행됩니다.

```powershell
docker compose -f docker-compose.prod.yml exec backend python manage.py createsuperuser
```

스터디를 이미 등록해둔 DB를 옮겨온 경우에는 회원 등급을 한 번 맞춰줍니다.

```powershell
docker compose -f docker-compose.prod.yml exec backend python manage.py sync_leader_roles --dry-run
docker compose -f docker-compose.prod.yml exec backend python manage.py sync_leader_roles
```

#### 코드를 고친 뒤 서버에 반영하기

```powershell
git pull
docker compose -f docker-compose.prod.yml up -d --build
```

바뀐 이미지만 다시 빌드하고 컨테이너를 교체합니다. 회원·게시글 데이터는 `postgres_data` 볼륨에 있어서 그대로 남습니다.

> `docker compose ... down -v`의 `-v`는 **볼륨까지 삭제**합니다. DB가 통째로 날아가므로 습관적으로 붙이지 마세요.

#### 상태 확인

```powershell
docker compose -f docker-compose.prod.yml ps
docker compose -f docker-compose.prod.yml logs -f backend
```

## 회원 CSV 일괄 생성

CSV(콤마/탭/세미콜론 구분자 자동 인식) 헤더를 `학번,이름,회원상태`로 작성합니다. `회원상태`는 `정회원`/`휴회원`/`스터디장`/`운영진` 중 하나이며 비워두면 정회원으로 생성됩니다.

```powershell
cd backend
python manage.py import_members members.csv
```

초기 비밀번호는 `kuics!학번` 형식으로 고정 부여되고 `must_change_password=true`로 생성되어 최초 로그인 시 비밀번호 변경이 강제됩니다. 이미 등록된 학번은 건너뛰므로, 모집 중 새 명단이 들어올 때마다 CSV를 갱신해 같은 명령을 재실행하면 됩니다. 학번/이름이 담긴 CSV(`backend/members*.csv`)는 개인정보이므로 커밋하지 않습니다.

## 구현 범위

- Home 및 전체 메뉴의 반응형 기본 레이아웃
- Study 학기 선택, 스터디 아코디언, 수료/우수수료 표시
- Django Admin 기반 학기·스터디·참여자·게시글 관리
- 학번 기반 세션 인증 API와 3단계 역할 모델
- 마이페이지, 과제 제출, 행사 기능의 확장용 골격
- API 로딩·빈 결과·오류 UI

DMOJ 연동, 실제 파일 업로드, 마이페이지 데이터 집계, 운영 배포 자동화는 후속 범위입니다.

자세한 규칙과 API는 [DEVELOPMENT_GUIDE.md](./DEVELOPMENT_GUIDE.md) 및 [docs/API.md](./docs/API.md)를 참고하세요.
