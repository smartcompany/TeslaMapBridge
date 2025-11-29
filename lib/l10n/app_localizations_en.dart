// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Navi to Tesla';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get defaultNavigationApp => 'Default navigation app';

  @override
  String get teslaNavigationModeTitle => 'Navigation mode';

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
  String get teslaVehicleSelection => 'Select vehicle';

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
  String get creditsAddedTitle => 'Credits added';

  @override
  String creditsAddedMessage(Object added, Object total) {
    return '$added credits added. Total balance: $total credits.';
  }

  @override
  String get creditsAddedDismiss => 'OK';

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
  String get loginTitle => 'Vehicle Account Login';

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
  String get navAppAppleMaps => 'Apple Maps';

  @override
  String get navAppGoogleMaps => 'Google Maps';

  @override
  String get addFavoriteTooltip => 'Add to favorites';

  @override
  String get removeFavoriteTooltip => 'Remove from favorites';

  @override
  String get favoriteNameDialogTitle => 'Add favorite';

  @override
  String get favoriteNameDialogHint => 'Enter a name (e.g. Home)';

  @override
  String get favoriteNameDialogCancel => 'Cancel';

  @override
  String get favoriteNameDialogSave => 'Save';

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
      'No credits remain. Purchase credits to continue.';

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
    return '$total credits remaining';
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
  String get oneTimePurchaseButton => 'Purchase';

  @override
  String get creditsSectionTitle => 'Credits';

  @override
  String creditsOwnedLabel(Object count) {
    return 'Credits: $count';
  }

  @override
  String creditsBenefitLabel(Object percent) {
    return '+$percent% benefit';
  }

  @override
  String get buyCredits => 'Buy credits';

  @override
  String get earnFreeCredits => 'Earn free credits (Watch ad)';

  @override
  String get rewardTitle => 'Get free credits';

  @override
  String rewardDescription(Object count) {
    return 'Watch a short ad to earn $count credits. Credits are used when sending routes to your vehicle.';
  }

  @override
  String get watchAd => 'Watch ad';

  @override
  String rewardEarned(Object count) {
    return '$count credits have been added!';
  }

  @override
  String get creditsUpdated => 'Credits updated.';

  @override
  String get rewardNotCompleted =>
      'You need to watch the full ad to earn credits.';

  @override
  String get rewardAdLoadFailed =>
      'Unable to load ad right now. Please try again later.';

  @override
  String get oneTimePurchaseRequiredMessage =>
      'No credits remain. Purchase credits to continue.';

  @override
  String get oneTimePurchaseActiveLabel => 'Your purchase is active.';

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

  @override
  String get rewardAdMustFinish =>
      'You must watch the ad to the end to receive credits.';

  @override
  String get favorites => 'Favorites';

  @override
  String get noRecentDestinations => 'No recent destinations.';

  @override
  String get noFavorites => 'No saved favorites.';

  @override
  String get deleteFavorite => 'Delete favorite';

  @override
  String get confirmDeleteFavorite => 'Delete Favorite';

  @override
  String confirmDeleteFavoriteMessage(Object name) {
    return 'Delete $name from favorites?';
  }

  @override
  String get delete => 'Delete';

  @override
  String get deleteRecentDestination => 'Delete recent destination';

  @override
  String get confirmDeleteRecentDestination => 'Delete Recent Destination';

  @override
  String confirmDeleteRecentDestinationMessage(Object name) {
    return 'Delete $name from recent destinations?';
  }
}
