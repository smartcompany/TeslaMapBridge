// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'テスラマップブリッジ';

  @override
  String get settingsTitle => '設定';

  @override
  String get defaultNavigationApp => 'デフォルトのナビアプリ';

  @override
  String get teslaNavigationModeTitle => 'テスラナビゲーション方式';

  @override
  String get teslaNavigationModeDestination => '目的地情報を送信';

  @override
  String get teslaNavigationModeGps => 'GPS 座標を送信';

  @override
  String navigationSetConfirmation(Object appName) {
    return '$appName をデフォルトのナビアプリに設定しました。';
  }

  @override
  String get logoutTitle => 'ログアウト';

  @override
  String get logoutDescription => 'アカウントからログアウトします';

  @override
  String get logoutConfirmation => 'ログアウトしますか？';

  @override
  String get cancel => 'キャンセル';

  @override
  String get logoutButton => 'ログアウト';

  @override
  String get searchHint => '目的地を検索';

  @override
  String get recentSearches => '最近のドライブ地点';

  @override
  String get teslaVehicleSelection => 'テスラ車を選択';

  @override
  String get noVehiclesMessage =>
      '登録済みの車両がないか読み込めませんでした。\nTesla アプリを確認して更新してください。';

  @override
  String get refreshVehicles => '車両を更新';

  @override
  String get sendingToTesla => 'テスラ車に送信中...';

  @override
  String get startNavigation => 'ナビを開始';

  @override
  String get teslaVehicleRequired => '先にテスラ車を選択してください。';

  @override
  String get sendToTeslaSuccess => 'テスラ車に目的地を送信しました。';

  @override
  String get sendToTeslaFailure => 'テスラ車への送信に失敗しました。';

  @override
  String get navigationStarted => 'ナビを開始しました。';

  @override
  String get navigationFailed => 'ナビを開始できませんでした。';

  @override
  String get selectDestinationPrompt => '目的地を選択してください。';

  @override
  String failedToFetchPlaceDetails(Object error) {
    return '場所情報の取得に失敗しました: $error';
  }

  @override
  String errorWithMessage(Object error) {
    return 'エラー: $error';
  }

  @override
  String get unknownPlace => '不明な場所';

  @override
  String get loginTitle => 'テスラログイン';

  @override
  String get initializing => '初期化中...';

  @override
  String get webViewInitializationFailed => 'WebView の初期化に失敗しました';

  @override
  String get processingLogin => 'ログイン処理中...';

  @override
  String get loading => '読み込み中...';

  @override
  String get loginFailed => 'ログインに失敗しました。もう一度お試しください。';

  @override
  String get clientIdNotConfigured =>
      'Client ID が設定されていません。\nlib/services/tesla_auth_service.dart の _clientId に Tesla Developer Portal の資格情報を設定してください。';

  @override
  String vehicleDefaultName(Object id) {
    return '車両 $id';
  }

  @override
  String get navAppTmap => 'Tmap';

  @override
  String get navAppNaver => 'Naver マップ';

  @override
  String get navAppKakao => 'カカオナビ';

  @override
  String get navAppAtlan => 'アトラン';

  @override
  String get navAppGoogleMaps => 'Google マップ';

  @override
  String get navAppWaze => 'Waze';

  @override
  String get navAppBaiduMaps => '百度地図';

  @override
  String get navAppGaodeMaps => '高徳地図 (AMap)';

  @override
  String get navAppTencentMaps => 'テンセント地図';

  @override
  String get navAppYahooCarNavi => 'Yahoo!カーナビ';

  @override
  String get navAppNavitime => 'NAVITIME';
}
