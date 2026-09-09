# pubspec.lock이 flutter >=3.44.0 / dart >=3.12.0을 요구한다.
# 이보다 낮은 이미지를 쓰면 flutter pub get 단계에서 SDK 제약 오류로 빌드가 실패한다.
FROM ghcr.io/cirruslabs/flutter:3.44.9 AS build
WORKDIR /app
COPY . .
RUN flutter pub get
# API_BASE_URL을 상대 경로로 빌드해야, 프론트를 서빙하는 도메인이 그대로
# API 요청 origin이 되어 CORS/CSRF/쿠키 문제 없이 동작한다 (같은 도메인 배포 전제).
RUN flutter build web --release --dart-define=API_BASE_URL=/api

FROM nginx:1.27-alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
