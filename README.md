# 테슬라 맵 브릿지

T맵, 네이버 네비, 카카오 네비와 테슬라 차량을 동시에 연결하여 길 안내를 시작하는 브릿징 앱입니다.

## 주요 기능

- ✅ 구글 지도를 이용한 목적지 검색 및 자동완성
- ✅ 네비게이션 앱 선택 (T맵, 네이버 네비, 카카오 네비)
- ✅ 선택된 네비게이션 앱에서 길 안내 시작
- ✅ 테슬라 차량에도 동시에 길 안내 전송
- ✅ 테슬라 로그인 및 자동 로그인 유지

## 설정 방법

### 1. Google Maps API 키 설정

1. [Google Cloud Console](https://console.cloud.google.com/)에서 프로젝트 생성
2. Google Maps SDK for Android, Google Maps SDK for iOS, Places API 활성화
3. API 키 생성 및 제한 설정

#### Android 설정

`android/app/src/main/AndroidManifest.xml` 파일에 다음을 추가:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
```

#### iOS 설정

`ios/Runner/AppDelegate.swift` 파일에 다음을 추가:

```swift
import GoogleMaps

// AppDelegate 클래스의 didFinishLaunchingWithOptions 메서드에 추가
GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
```

또는 `ios/Runner/Info.plist` 파일에 GMSApiKey를 설정 (이미 추가됨)

### 2. Google Places API 키 설정

`lib/screens/home_screen.dart` 파일에서 `_googlePlacesApiKey` 변수를 실제 API 키로 변경:

```dart
static const String _googlePlacesApiKey = 'YOUR_GOOGLE_PLACES_API_KEY';
```

### 3. 테슬라 API 인증

테슬라 API는 OAuth 2.0을 사용합니다. 현재 구현은 기본 인증 방식을 사용하지만, MFA(Multi-Factor Authentication)가 활성화된 계정의 경우 추가 설정이 필요할 수 있습니다.

## 설치 및 실행

```bash
# 의존성 설치
flutter pub get

# iOS 실행
flutter run -d ios

# Android 실행
flutter run -d android
```

## 네비게이션 앱 URL 스킴

### T맵
```
tmap://route?goalx=경도&goaly=위도&goalname=목적지명
```

### 네이버 네비
```
nmap://route?dlat=위도&dlng=경도&dname=목적지명
```

### 카카오 네비
```
kakaomap://route?ep=위도,경도&by=CAR&name=목적지명
또는
kakaonavi://navigate?name=목적지명&x=경도&y=위도
```

## 주의사항

1. **Google Maps API 키**: 반드시 실제 API 키를 설정해야 합니다. API 키 없이는 지도와 자동완성이 작동하지 않습니다.

2. **테슬라 API**: 테슬라 API는 MFA가 활성화된 계정의 경우 추가 인증이 필요할 수 있습니다. 로그인에 문제가 있으면 테슬라 계정 설정을 확인하세요.

3. **네비게이션 앱**: 각 네비게이션 앱이 기기에 설치되어 있어야 합니다.

4. **권한**: 인터넷 권한은 이미 설정되어 있습니다.

## 문제 해결

### 로그인 실패
- 테슬라 계정 이메일과 비밀번호가 정확한지 확인
- MFA가 활성화된 경우, 테슬라 앱에서 앱 비밀번호를 생성하여 사용
- 네트워크 연결 확인

### 지도가 표시되지 않음
- Google Maps API 키가 올바르게 설정되었는지 확인
- API 키의 제한 사항 확인 (앱 번들 ID, 패키지 이름 등)

### 네비게이션 앱이 실행되지 않음
- 해당 네비게이션 앱이 설치되어 있는지 확인
- URL 스킴이 올바른지 확인

## 라이선스

이 프로젝트는 개인 사용을 위한 것입니다.

## API Commands 요금

- 1,000회 = $1
- 즉 1회 = $0.001 (≈ 0.001 USD)
- 환율 1,350원 기준 → 1회 ≈ 1.35원
