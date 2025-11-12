// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '테슬라 맵 브리지';

  @override
  String get settingsTitle => '설정';

  @override
  String get defaultNavigationApp => '기본 네비게이션 앱';

  @override
  String get teslaNavigationModeTitle => '테슬라 내비게이션 방식';

  @override
  String get teslaNavigationModeDestination => '목적지 정보 전송';

  @override
  String get teslaNavigationModeGps => 'GPS 좌표 전송';

  @override
  String navigationSetConfirmation(Object appName) {
    return '$appName가 기본 네비게이션으로 설정되었습니다.';
  }

  @override
  String get logoutTitle => '로그아웃';

  @override
  String get logoutDescription => '계정에서 로그아웃합니다';

  @override
  String get logoutConfirmation => '로그아웃 하시겠습니까?';

  @override
  String get cancel => '취소';

  @override
  String get logoutButton => '로그아웃';

  @override
  String get searchHint => '목적지를 검색하세요';

  @override
  String get recentSearches => '최근 주행한 장소';

  @override
  String get teslaVehicleSelection => '테슬라 차량 선택';

  @override
  String get noVehiclesMessage =>
      '등록된 차량이 없거나 불러오지 못했습니다.\nTesla 앱에서 차량을 확인한 후 새로고침하세요.';

  @override
  String get refreshVehicles => '차량 새로고침';

  @override
  String get sendingToTesla => '테슬라 차량으로 전송 중...';

  @override
  String get startNavigation => '길 안내 시작';

  @override
  String get teslaVehicleRequired => '테슬라 차량을 먼저 선택해주세요.';

  @override
  String get sendToTeslaSuccess => '테슬라 차량에 목적지가 전송되었습니다.';

  @override
  String get sendToTeslaFailure => '테슬라 차량 전송에 실패했습니다.';

  @override
  String get navigationStarted => '길 안내가 시작되었습니다.';

  @override
  String get navigationFailed => '길 안내를 시작하지 못했습니다.';

  @override
  String get selectDestinationPrompt => '목적지를 선택해주세요.';

  @override
  String failedToFetchPlaceDetails(Object error) {
    return '장소 정보를 가져오는데 실패했습니다: $error';
  }

  @override
  String errorWithMessage(Object error) {
    return '오류 발생: $error';
  }

  @override
  String get unknownPlace => '알 수 없는 장소';

  @override
  String get loginTitle => '테슬라 로그인';

  @override
  String get initializing => '초기화 중...';

  @override
  String get webViewInitializationFailed => 'WebView 초기화 실패';

  @override
  String get processingLogin => '로그인 처리 중...';

  @override
  String get loading => '로딩 중...';

  @override
  String get loginFailed => '로그인에 실패했습니다. 다시 시도해주세요.';

  @override
  String get clientIdNotConfigured =>
      'Client ID가 설정되지 않았습니다.\nlib/services/tesla_auth_service.dart 파일에서\n_clientId를 Tesla Developer Portal에서 발급받은 값으로 설정하세요.';

  @override
  String vehicleDefaultName(Object id) {
    return '차량 $id';
  }

  @override
  String get navAppTmap => 'T맵';

  @override
  String get navAppNaver => '네이버 지도';

  @override
  String get navAppKakao => '카카오 네비';

  @override
  String get navAppAtlan => '아틀란';

  @override
  String get navAppGoogleMaps => '구글 지도';

  @override
  String get navAppWaze => 'Waze';

  @override
  String get navAppBaiduMaps => '바이두 지도';

  @override
  String get navAppGaodeMaps => '가오더 지도 (AMap)';

  @override
  String get navAppTencentMaps => '텐센트 지도';

  @override
  String get navAppYahooCarNavi => 'Yahoo! Car Navi';

  @override
  String get navAppNavitime => 'NAVITIME';

  @override
  String get subscriptionRequiredTitle => '구독이 필요합니다';

  @override
  String get subscriptionRequiredMessage =>
      '무료 사용 횟수를 모두 사용했습니다. 계속 이용하려면 구독하세요.';

  @override
  String get subscriptionRequiredButton => '구독 보기';

  @override
  String remainingFreeDrives(Object count) {
    return '무료 이용 $count회 남았습니다';
  }

  @override
  String get subscriptionSectionTitle => '구독 및 요금제';

  @override
  String get subscriptionDescription => '';

  @override
  String subscriptionUsageStatus(int total) {
    return '무료 이용 $total회가 남았습니다';
  }

  @override
  String get subscriptionUpgradeButton => '지금 구독하기';

  @override
  String get subscriptionRestoreButton => '구매 항목 복원';

  @override
  String get subscriptionProcessing => '구매를 처리하는 중입니다…';

  @override
  String get subscriptionActiveLabel => '구독이 활성화되었습니다.';

  @override
  String subscriptionErrorLabel(String message) {
    return '구매에 실패했습니다: $message';
  }

  @override
  String get subscriptionComingSoon => '';

  @override
  String get subscriptionLoading => '플랜을 확인하는 중...';

  @override
  String get debugAccessTokenTitle => '디버그: Tesla 액세스 토큰';

  @override
  String get debugAccessTokenCopy => '토큰 복사';

  @override
  String get debugAccessTokenCopied => '액세스 토큰을 클립보드에 복사했어요.';

  @override
  String get debugAccessTokenRefresh => '새로고침';

  @override
  String get debugAccessTokenRefreshed => '액세스 토큰을 새로고침했습니다.';

  @override
  String get debugAccessTokenEmpty => '액세스 토큰을 보려면 Tesla 계정으로 로그인하세요.';
}
