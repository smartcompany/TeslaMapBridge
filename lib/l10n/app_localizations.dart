import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
    Locale('zh'),
    Locale('ja'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Tesla Map Bridge'**
  String get appTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @defaultNavigationApp.
  ///
  /// In en, this message translates to:
  /// **'Default navigation app'**
  String get defaultNavigationApp;

  /// No description provided for @teslaNavigationModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Tesla navigation preference'**
  String get teslaNavigationModeTitle;

  /// No description provided for @teslaNavigationModeDestination.
  ///
  /// In en, this message translates to:
  /// **'Use destination details'**
  String get teslaNavigationModeDestination;

  /// No description provided for @teslaNavigationModeGps.
  ///
  /// In en, this message translates to:
  /// **'Use GPS coordinates'**
  String get teslaNavigationModeGps;

  /// No description provided for @navigationSetConfirmation.
  ///
  /// In en, this message translates to:
  /// **'{appName} has been set as the default navigation app.'**
  String navigationSetConfirmation(Object appName);

  /// No description provided for @logoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logoutTitle;

  /// No description provided for @logoutDescription.
  ///
  /// In en, this message translates to:
  /// **'Log out of your account'**
  String get logoutDescription;

  /// No description provided for @logoutConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Do you want to log out?'**
  String get logoutConfirmation;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @logoutButton.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logoutButton;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search for a destination'**
  String get searchHint;

  /// No description provided for @recentSearches.
  ///
  /// In en, this message translates to:
  /// **'Recent drives'**
  String get recentSearches;

  /// No description provided for @teslaVehicleSelection.
  ///
  /// In en, this message translates to:
  /// **'Select Tesla vehicle'**
  String get teslaVehicleSelection;

  /// No description provided for @noVehiclesMessage.
  ///
  /// In en, this message translates to:
  /// **'No vehicles found or failed to load.\nCheck the Tesla app and refresh.'**
  String get noVehiclesMessage;

  /// No description provided for @refreshVehicles.
  ///
  /// In en, this message translates to:
  /// **'Refresh vehicles'**
  String get refreshVehicles;

  /// No description provided for @sendingToTesla.
  ///
  /// In en, this message translates to:
  /// **'Sending to Tesla vehicle...'**
  String get sendingToTesla;

  /// No description provided for @startNavigation.
  ///
  /// In en, this message translates to:
  /// **'Start navigation'**
  String get startNavigation;

  /// No description provided for @teslaVehicleRequired.
  ///
  /// In en, this message translates to:
  /// **'Select a Tesla vehicle first.'**
  String get teslaVehicleRequired;

  /// No description provided for @sendToTeslaSuccess.
  ///
  /// In en, this message translates to:
  /// **'Destination sent to Tesla vehicle.'**
  String get sendToTeslaSuccess;

  /// No description provided for @sendToTeslaFailure.
  ///
  /// In en, this message translates to:
  /// **'Failed to send destination to Tesla vehicle.'**
  String get sendToTeslaFailure;

  /// No description provided for @navigationStarted.
  ///
  /// In en, this message translates to:
  /// **'Navigation started.'**
  String get navigationStarted;

  /// No description provided for @navigationFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to start navigation.'**
  String get navigationFailed;

  /// No description provided for @selectDestinationPrompt.
  ///
  /// In en, this message translates to:
  /// **'Please select a destination.'**
  String get selectDestinationPrompt;

  /// No description provided for @failedToFetchPlaceDetails.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch place details: {error}'**
  String failedToFetchPlaceDetails(Object error);

  /// No description provided for @errorWithMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorWithMessage(Object error);

  /// No description provided for @unknownPlace.
  ///
  /// In en, this message translates to:
  /// **'Unknown place'**
  String get unknownPlace;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Tesla Login'**
  String get loginTitle;

  /// No description provided for @initializing.
  ///
  /// In en, this message translates to:
  /// **'Initializing...'**
  String get initializing;

  /// No description provided for @webViewInitializationFailed.
  ///
  /// In en, this message translates to:
  /// **'WebView initialization failed'**
  String get webViewInitializationFailed;

  /// No description provided for @processingLogin.
  ///
  /// In en, this message translates to:
  /// **'Processing login...'**
  String get processingLogin;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Please try again.'**
  String get loginFailed;

  /// No description provided for @clientIdNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Client ID is not configured.\nSet _clientId with your Tesla Developer Portal credentials in lib/services/tesla_auth_service.dart.'**
  String get clientIdNotConfigured;

  /// No description provided for @vehicleDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Vehicle {id}'**
  String vehicleDefaultName(Object id);

  /// No description provided for @navAppTmap.
  ///
  /// In en, this message translates to:
  /// **'Tmap'**
  String get navAppTmap;

  /// No description provided for @navAppNaver.
  ///
  /// In en, this message translates to:
  /// **'Naver Map'**
  String get navAppNaver;

  /// No description provided for @navAppKakao.
  ///
  /// In en, this message translates to:
  /// **'Kakao Navi'**
  String get navAppKakao;

  /// No description provided for @navAppAtlan.
  ///
  /// In en, this message translates to:
  /// **'Atlan'**
  String get navAppAtlan;

  /// No description provided for @navAppGoogleMaps.
  ///
  /// In en, this message translates to:
  /// **'Google Maps'**
  String get navAppGoogleMaps;

  /// No description provided for @navAppWaze.
  ///
  /// In en, this message translates to:
  /// **'Waze'**
  String get navAppWaze;

  /// No description provided for @navAppBaiduMaps.
  ///
  /// In en, this message translates to:
  /// **'Baidu Maps'**
  String get navAppBaiduMaps;

  /// No description provided for @navAppGaodeMaps.
  ///
  /// In en, this message translates to:
  /// **'Gaode (AMap)'**
  String get navAppGaodeMaps;

  /// No description provided for @navAppTencentMaps.
  ///
  /// In en, this message translates to:
  /// **'Tencent Maps'**
  String get navAppTencentMaps;

  /// No description provided for @navAppYahooCarNavi.
  ///
  /// In en, this message translates to:
  /// **'Yahoo! Car Navi'**
  String get navAppYahooCarNavi;

  /// No description provided for @navAppNavitime.
  ///
  /// In en, this message translates to:
  /// **'NAVITIME'**
  String get navAppNavitime;

  /// No description provided for @subscriptionRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription required'**
  String get subscriptionRequiredTitle;

  /// No description provided for @subscriptionRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'You have used all free trips. Subscribe to continue using navigation.'**
  String get subscriptionRequiredMessage;

  /// No description provided for @subscriptionRequiredButton.
  ///
  /// In en, this message translates to:
  /// **'View plans'**
  String get subscriptionRequiredButton;

  /// No description provided for @remainingFreeDrives.
  ///
  /// In en, this message translates to:
  /// **'{count} free trips left'**
  String remainingFreeDrives(Object count);

  /// No description provided for @subscriptionSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription & plans'**
  String get subscriptionSectionTitle;

  /// No description provided for @subscriptionDescription.
  ///
  /// In en, this message translates to:
  /// **''**
  String get subscriptionDescription;

  /// No description provided for @subscriptionUsageStatus.
  ///
  /// In en, this message translates to:
  /// **'{total} free trips remaining'**
  String subscriptionUsageStatus(int total);

  /// No description provided for @subscriptionUpgradeButton.
  ///
  /// In en, this message translates to:
  /// **'Upgrade plan'**
  String get subscriptionUpgradeButton;

  /// No description provided for @subscriptionComingSoon.
  ///
  /// In en, this message translates to:
  /// **'In-app subscriptions are coming soon. We\'ll notify you when purchasing is available.'**
  String get subscriptionComingSoon;

  /// No description provided for @subscriptionLoading.
  ///
  /// In en, this message translates to:
  /// **'Checking your plan...'**
  String get subscriptionLoading;

  /// No description provided for @debugAccessTokenTitle.
  ///
  /// In en, this message translates to:
  /// **'Debug: Tesla access token'**
  String get debugAccessTokenTitle;

  /// No description provided for @debugAccessTokenCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy token'**
  String get debugAccessTokenCopy;

  /// No description provided for @debugAccessTokenCopied.
  ///
  /// In en, this message translates to:
  /// **'Access token copied to clipboard.'**
  String get debugAccessTokenCopied;

  /// No description provided for @debugAccessTokenRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get debugAccessTokenRefresh;

  /// No description provided for @debugAccessTokenRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Access token refreshed.'**
  String get debugAccessTokenRefreshed;

  /// No description provided for @debugAccessTokenEmpty.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Tesla to view the access token.'**
  String get debugAccessTokenEmpty;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'ko', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
