#!/usr/bin/env bash
# Vercel 빌드 환경에는 Flutter SDK가 없으므로 빌드 시점에 내려받아 사용한다.
set -euo pipefail

FLUTTER_DIR="$HOME/flutter"

if [ ! -d "$FLUTTER_DIR" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

flutter --version
flutter pub get
# API_BASE_URL을 상대 경로로 두면 vercel.json의 rewrites가 /api를 백엔드로 전달하므로
# 브라우저 입장에서는 프론트와 API가 같은 도메인이 된다.
flutter build web --release --dart-define=API_BASE_URL=/api
