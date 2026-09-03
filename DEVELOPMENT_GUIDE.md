# Development Guide

## 원칙

- `frontend/`는 DB에 직접 접근하지 않고 `/api`만 호출합니다.
- 인증·권한·입력 검증은 반드시 Django에서 수행합니다.
- `AUTH_USER_MODEL`은 최초 migration 전부터 `accounts.Member`로 유지합니다.
- 모델 변경과 migration은 같은 PR에 포함합니다.
- `.env`, 회원 CSV, 비밀번호, 토큰, DB 백업은 커밋하지 않습니다.
- 운영 서버의 코드는 직접 수정하지 않고 GitHub 이력으로 배포합니다.

## 역할

- `member`: 공개 정보 및 본인 정보 조회
- `leader`: 본인이 담당하는 스터디의 참여 상태 변경
- `admin`: 전체 데이터 관리 및 Django Admin 사용

프론트엔드에서 버튼을 숨기는 것과 별개로 API permission에서 역할을 다시 검사합니다.

## 권장 작업 순서

1. 모델 변경 및 migration 생성
2. serializer와 API 수정
3. backend 권한·응답 테스트
4. Flutter model/API client 수정
5. 로딩·빈 결과·오류 상태를 포함한 UI 수정
6. `flutter analyze`, `flutter test`, Django test 실행

## 로컬 점검

```powershell
cd backend
python manage.py check
python manage.py test

cd ..\frontend
flutter analyze
flutter test
flutter build web
```

쿠키 기반 세션 인증을 사용하므로 배포 시 프론트엔드와 API를 같은 도메인의 `/api`로 reverse proxy하는 구성을 권장합니다. 도메인이 분리되면 CORS, CSRF, Secure/SameSite 쿠키 정책을 함께 조정해야 합니다.

