# 설정 가이드

## 필수 설정

### 1. Google Maps API 키 발급 및 설정

1. [Google Cloud Console](https://console.cloud.google.com/) 접속
2. 새 프로젝트 생성 또는 기존 프로젝트 선택
3. 다음 API 활성화:
   - Maps SDK for Android
   - Maps SDK for iOS
   - Places API
   - Geocoding API (선택사항)

4. API 키 생성:
   - "사용자 인증 정보" → "사용자 인증 정보 만들기" → "API 키"
   - 생성된 API 키를 복사

5. API 키 설정:
   - Android: `android/app/src/main/AndroidManifest.xml`에서 `YOUR_GOOGLE_MAPS_API_KEY` 교체
   - iOS: `ios/Runner/AppDelegate.swift`에서 `YOUR_GOOGLE_MAPS_API_KEY` 교체
   - 코드: `lib/screens/home_screen.dart`에서 `_googlePlacesApiKey` 변수 값 교체

6. API 키 제한 설정 (보안 권장):
   - Android: 패키지 이름 제한 추가
   - iOS: 번들 ID 제한 추가
   - HTTP 리퍼러 제한 (웹 사용 시)

### 2. 테슬라 계정 준비

- 테슬라 계정 이메일과 비밀번호 필요
- MFA(Multi-Factor Authentication)가 활성화된 경우:
  - 테슬라 앱에서 "설정" → "보안" → "앱 비밀번호" 생성
  - 생성된 앱 비밀번호를 사용

### 3. 네비게이션 앱 설치

- T맵, 네이버 네비, 카카오 네비 중 최소 하나 이상 설치 필요

## 실행

```bash
# 의존성 설치
cd tesla_map_bridge
flutter pub get

# iOS 실행 (Mac만 가능)
flutter run -d ios

# Android 실행
flutter run -d android
```

## 문제 해결

### Google Maps가 표시되지 않음
- API 키가 올바르게 설정되었는지 확인
- API가 활성화되었는지 확인
- API 키 제한 설정 확인

### 테슬라 로그인 실패
- 이메일과 비밀번호 확인
- MFA가 활성화된 경우 앱 비밀번호 사용
- 네트워크 연결 확인
- 테슬라 API 상태 확인

### 네비게이션 앱이 실행되지 않음
- 해당 앱이 설치되어 있는지 확인
- URL 스킴이 올바른지 확인 (최신 버전의 앱일 수 있음)

