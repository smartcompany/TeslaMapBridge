// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Tesla Map Bridge';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get defaultNavigationApp => 'Default navigation app';

  @override
  String get teslaNavigationModeTitle => 'Tesla navigation preference';

  @override
  String get teslaNavigationModeDestination => 'Use destination details';

  @override
  String get teslaNavigationModeGps => 'Use GPS coordinates';

  @override
  String navigationSetConfirmation(Object appName) {
    return '$appName has been set as the default navigation app.';
  }

  @override
  String get logoutTitle => 'Log out';

  @override
  String get logoutDescription => 'Log out of your account';

  @override
  String get logoutConfirmation => 'Do you want to log out?';

  @override
  String get cancel => 'Cancel';

  @override
  String get logoutButton => 'Log out';

  @override
  String get searchHint => 'Search for a destination';

  @override
  String get recentSearches => 'Recent drives';

  @override
  String get teslaVehicleSelection => 'Select Tesla vehicle';

  @override
  String get noVehiclesMessage =>
      'No vehicles found or failed to load.\nCheck the Tesla app and refresh.';

  @override
  String get refreshVehicles => 'Refresh vehicles';

  @override
  String get sendingToTesla => 'Sending to Tesla vehicle...';

  @override
  String get startNavigation => 'Start navigation';

  @override
  String get teslaVehicleRequired => 'Select a Tesla vehicle first.';

  @override
  String get sendToTeslaSuccess => 'Destination sent to Tesla vehicle.';

  @override
  String get sendToTeslaFailure =>
      'Failed to send destination to Tesla vehicle.';

  @override
  String get navigationStarted => 'Navigation started.';

  @override
  String get navigationFailed => 'Failed to start navigation.';

  @override
  String get selectDestinationPrompt => 'Please select a destination.';

  @override
  String failedToFetchPlaceDetails(Object error) {
    return 'Failed to fetch place details: $error';
  }

  @override
  String errorWithMessage(Object error) {
    return 'Error: $error';
  }

  @override
  String get unknownPlace => 'Unknown place';

  @override
  String get loginTitle => 'Tesla Login';

  @override
  String get initializing => 'Initializing...';

  @override
  String get webViewInitializationFailed => 'WebView initialization failed';

  @override
  String get processingLogin => 'Processing login...';

  @override
  String get loading => 'Loading...';

  @override
  String get loginFailed => 'Login failed. Please try again.';

  @override
  String get clientIdNotConfigured =>
      'Client ID is not configured.\nSet _clientId with your Tesla Developer Portal credentials in lib/services/tesla_auth_service.dart.';

  @override
  String vehicleDefaultName(Object id) {
    return 'Vehicle $id';
  }

  @override
  String get navAppTmap => 'Tmap';

  @override
  String get navAppNaver => 'Naver Map';

  @override
  String get navAppKakao => 'Kakao Navi';

  @override
  String get navAppAtlan => 'Atlan';

  @override
  String get navAppGoogleMaps => 'Google Maps';

  @override
  String get navAppWaze => 'Waze';

  @override
  String get navAppBaiduMaps => 'Baidu Maps';

  @override
  String get navAppGaodeMaps => 'Gaode (AMap)';

  @override
  String get navAppTencentMaps => 'Tencent Maps';

  @override
  String get navAppYahooCarNavi => 'Yahoo! Car Navi';

  @override
  String get navAppNavitime => 'NAVITIME';

  @override
  String get subscriptionRequiredTitle => 'Subscription required';

  @override
  String get subscriptionRequiredMessage =>
      'You have used all free trips. Subscribe to continue using navigation.';

  @override
  String get subscriptionRequiredButton => 'View plans';

  @override
  String remainingFreeDrives(Object count) {
    return '$count free trips left';
  }

  @override
  String get subscriptionSectionTitle => 'Subscription & plans';

  @override
  String get subscriptionDescription =>
      'Enjoy 10 free trips on us. Upgrade to unlock unlimited navigation, cross-device history sync, and upcoming automation features.';

  @override
  String subscriptionUsageStatus(int total) {
    return '$total free trips remaining';
  }

  @override
  String get subscriptionUpgradeButton => 'Upgrade plan';

  @override
  String get subscriptionComingSoon =>
      'In-app subscriptions are coming soon. We\'ll notify you when purchasing is available.';

  @override
  String get subscriptionLoading => 'Checking your plan...';

  @override
  String get debugAccessTokenTitle => 'Debug: Tesla access token';

  @override
  String get debugAccessTokenCopy => 'Copy token';

  @override
  String get debugAccessTokenCopied => 'Access token copied to clipboard.';

  @override
  String get debugAccessTokenRefresh => 'Refresh';

  @override
  String get debugAccessTokenRefreshed => 'Access token refreshed.';

  @override
  String get debugAccessTokenEmpty =>
      'Sign in with Tesla to view the access token.';
}
