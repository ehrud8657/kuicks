# KUICS Flutter Web

`lib/main.dart`에 공통 셸과 화면이, `lib/api_client.dart`에 Django API 호출이, `lib/models.dart`에 응답 모델이 있습니다.

API 주소는 빌드 시 지정합니다.

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000/api
```
