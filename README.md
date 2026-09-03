# KUICS Homepage

고려대학교 정보보호 동아리 KUICS의 신규 홈페이지 모노레포입니다. 기존 DMOJ 사이트와 분리하여 운영하며, Flutter Web 프론트엔드와 Django REST Framework 백엔드로 구성합니다.

## 구성

```text
quicks/
├─ frontend/            Flutter Web
├─ backend/             Django + DRF
│  ├─ apps/accounts/    학번 로그인, 회원, CSV 일괄 생성
│  ├─ apps/studies/     학기, 스터디, 참여, 과제 제출 골격
│  ├─ apps/boards/      공지사항 및 모집공고
│  └─ apps/activities/  행사 및 참여 골격
├─ docs/                설계 및 API 문서
└─ docker-compose.yml   PostgreSQL + backend 개발 환경
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

### Docker로 DB와 Backend 실행

```powershell
Copy-Item .env.example .env
docker compose up --build
```

첫 실행 후 별도 터미널에서 migration과 운영진 계정을 만듭니다.

```powershell
docker compose exec backend python manage.py makemigrations accounts studies boards activities
docker compose exec backend python manage.py migrate
docker compose exec backend python manage.py createsuperuser
```

## 회원 CSV 일괄 생성

UTF-8 CSV의 헤더를 `학번,이름`으로 작성합니다.

```powershell
cd backend
python manage.py import_members members.csv
```

명령은 임시 비밀번호를 한 번만 터미널에 출력하고 `must_change_password=true`로 계정을 생성합니다. 실서비스에서는 출력 결과를 안전하게 전달하고 즉시 폐기해야 합니다.

## 구현 범위

- Home 및 전체 메뉴의 반응형 기본 레이아웃
- Study 학기 선택, 스터디 아코디언, 수료/우수수료 표시
- Django Admin 기반 학기·스터디·참여자·게시글 관리
- 학번 기반 세션 인증 API와 3단계 역할 모델
- 마이페이지, 과제 제출, 행사 기능의 확장용 골격
- API 로딩·빈 결과·오류 UI

DMOJ 연동, 실제 파일 업로드, 마이페이지 데이터 집계, 운영 배포 자동화는 후속 범위입니다.

자세한 규칙과 API는 [DEVELOPMENT_GUIDE.md](./DEVELOPMENT_GUIDE.md) 및 [docs/API.md](./docs/API.md)를 참고하세요.
