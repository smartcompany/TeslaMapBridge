// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'CarMap Link';

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
  String get subscriptionDescription => '';

  @override
  String subscriptionUsageStatus(int total) {
    return '$total free trips remaining';
  }

  @override
  String get subscriptionUpgradeButton => 'Subscribe now';

  @override
  String get subscriptionRestoreButton => 'Restore purchases';

  @override
  String get subscriptionProcessing => 'Processing your purchase…';

  @override
  String get subscriptionActiveLabel => 'Your subscription is active.';

  @override
  String subscriptionErrorLabel(String message) {
    return 'Purchase failed: $message';
  }

  @override
  String get subscriptionComingSoon => '';

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

  @override
  String get themeSectionTitle => 'Appearance';

  @override
  String get themeDarkLabel => 'Dark mode';

  @override
  String get themeLightLabel => 'Light mode';

  @override
  String get themeChangedMessage => 'Theme updated.';

  @override
  String get networkErrorTitle => 'Network Connection Error';

  @override
  String get networkErrorMessage =>
      'Please check your internet connection and try again.';

  @override
  String get retry => 'Retry';

  @override
  String get close => 'Close';

  @override
  String get termsOfUse => 'Terms of Use';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsAndPrivacy => 'Terms / Privacy';

  @override
  String get legalSectionTitle => 'Legal';
}
