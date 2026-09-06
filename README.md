# KUICS Homepage

고려대학교 정보보호 동아리 KUICS의 신규 홈페이지 모노레포입니다. 기존 DMOJ 사이트와 분리하여 운영하며, Flutter Web 프론트엔드와 Django REST Framework 백엔드로 구성합니다.

## 구성

```text
kuicks/
├─ frontend/            Flutter Web (Dockerfile: flutter build + nginx)
├─ backend/             Django + DRF
│  ├─ apps/accounts/    학번 로그인, 회원, CSV 일괄 생성
│  ├─ apps/studies/     학기, 스터디, 참여, 과제 제출 골격
│  ├─ apps/boards/      공지사항 및 모집공고
│  └─ apps/activities/  행사 및 참여 골격
├─ docs/                설계 및 API 문서
└─ docker-compose.yml   PostgreSQL + backend + frontend(nginx) 전체 스택
```

## 빠른 시작

### Backend

Python 3.12 이상과 PostgreSQL을 권장합니다. `DATABASE_URL`이 없으면 로컬 SQLite를 사용합니다.

```powershell
cd backend
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python manage.py makemigrations accounts studies boards activities
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

### Docker로 전체 스택 실행 (같은 도메인 배포 구성)

`docker-compose.yml`은 실제 배포와 동일하게 **프론트(nginx)와 백엔드를 같은 도메인**으로 묶는 구성입니다. nginx가 `/`는 Flutter web 빌드 결과물을, `/api`·`/admin`·`/static`·`/media`는 backend로 라우팅하므로 브라우저 입장에선 항상 하나의 origin만 봅니다 — CORS/CSRF/쿠키 설정이 단순해지는 이유입니다. 프론트는 `API_BASE_URL=/api`(상대 경로)로 빌드되어 이 구조를 그대로 전제합니다.

```powershell
Copy-Item .env.example .env
docker compose up --build
```

`http://localhost`로 접속하면 프론트와 API가 동시에 뜹니다. 첫 실행 후 별도 터미널에서 migration과 운영진 계정을 만듭니다.

```powershell
docker compose exec backend python manage.py makemigrations accounts studies boards activities
docker compose exec backend python manage.py migrate
docker compose exec backend python manage.py createsuperuser
```

실제 배포 도메인이 정해지면 `.env`의 `CORS_ALLOWED_ORIGINS`만 그 주소로 바꾸면 됩니다. 프론트/백엔드를 서로 다른 서브도메인으로 나눠야 하는 경우에만 `CROSS_SITE_COOKIES=true`를 추가로 켭니다 (자세한 내용은 [DEVELOPMENT_GUIDE.md](./DEVELOPMENT_GUIDE.md) 참고).

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
