// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'CarMap Link';

  @override
  String get settingsTitle => '设置';

  @override
  String get defaultNavigationApp => '默认导航应用';

  @override
  String get teslaNavigationModeTitle => '特斯拉导航方式';

  @override
  String get teslaNavigationModeDestination => '发送目的地信息';

  @override
  String get teslaNavigationModeGps => '发送 GPS 坐标';

  @override
  String navigationSetConfirmation(Object appName) {
    return '$appName 已设为默认导航应用。';
  }

  @override
  String get logoutTitle => '注销';

  @override
  String get logoutDescription => '退出您的帐户';

  @override
  String get logoutConfirmation => '要注销吗？';

  @override
  String get cancel => '取消';

  @override
  String get logoutButton => '注销';

  @override
  String get searchHint => '搜索目的地';

  @override
  String get recentSearches => '最近行驶地点';

  @override
  String get teslaVehicleSelection => '选择特斯拉车辆';

  @override
  String get noVehiclesMessage => '未找到车辆或加载失败。\n请在 Tesla 应用中确认后刷新。';

  @override
  String get refreshVehicles => '刷新车辆';

  @override
  String get sendingToTesla => '正在发送到特斯拉车辆...';

  @override
  String get startNavigation => '开始导航';

  @override
  String get teslaVehicleRequired => '请先选择特斯拉车辆。';

  @override
  String get sendToTeslaSuccess => '已将目的地发送到特斯拉车辆。';

  @override
  String get sendToTeslaFailure => '发送目的地到特斯拉车辆失败。';

  @override
  String get navigationStarted => '导航已启动。';

  @override
  String get navigationFailed => '无法启动导航。';

  @override
  String get selectDestinationPrompt => '请选择目的地。';

  @override
  String failedToFetchPlaceDetails(Object error) {
    return '获取地点信息失败：$error';
  }

  @override
  String errorWithMessage(Object error) {
    return '错误：$error';
  }

  @override
  String get unknownPlace => '未知地点';

  @override
  String get loginTitle => '特斯拉登录';

  @override
  String get initializing => '初始化中...';

  @override
  String get webViewInitializationFailed => 'WebView 初始化失败';

  @override
  String get processingLogin => '正在处理登录...';

  @override
  String get loading => '加载中...';

  @override
  String get loginFailed => '登录失败。请重试。';

  @override
  String get clientIdNotConfigured =>
      '未配置 Client ID。\n请在 lib/services/tesla_auth_service.dart 中将 _clientId 设置为 Tesla 开发者门户提供的值。';

  @override
  String vehicleDefaultName(Object id) {
    return '车辆 $id';
  }

  @override
  String get navAppTmap => 'Tmap';

  @override
  String get navAppNaver => 'Naver 地图';

  @override
  String get navAppKakao => 'Kakao 导航';

  @override
  String get navAppAtlan => 'Atlan';

  @override
  String get navAppGoogleMaps => 'Google 地图';

  @override
  String get navAppWaze => 'Waze';

  @override
  String get navAppBaiduMaps => '百度地图';

  @override
  String get navAppGaodeMaps => '高德地图 (AMap)';

  @override
  String get navAppTencentMaps => '腾讯地图';

  @override
  String get navAppYahooCarNavi => 'Yahoo! Car Navi';

  @override
  String get navAppNavitime => 'NAVITIME';

  @override
  String get subscriptionRequiredTitle => '需要订阅';

  @override
  String get subscriptionRequiredMessage => '您已用完所有免费次数。订阅后即可继续使用导航。';

  @override
  String get subscriptionRequiredButton => '查看方案';

  @override
  String remainingFreeDrives(Object count) {
    return '剩余 $count 次免费导航';
  }

  @override
  String get subscriptionSectionTitle => '订阅与方案';

  @override
  String get subscriptionDescription => '';

  @override
  String subscriptionUsageStatus(int total) {
    return '剩余 $total 次免费导航';
  }

  @override
  String get subscriptionUpgradeButton => '立即订阅';

  @override
  String get subscriptionRestoreButton => '恢复购买';

  @override
  String get subscriptionProcessing => '正在处理您的购买…';

  @override
  String get subscriptionActiveLabel => '您的订阅已激活。';

  @override
  String subscriptionErrorLabel(String message) {
    return '购买失败：$message';
  }

  @override
  String get subscriptionComingSoon => '';

  @override
  String get subscriptionLoading => '正在检查您的方案...';

  @override
  String get oneTimePurchaseButton => '购买';

  @override
  String get creditsSectionTitle => '积分';

  @override
  String creditsOwnedLabel(Object count) {
    return '当前积分 $count';
  }

  @override
  String creditsBenefitLabel(Object percent) {
    return '+$percent% 优惠';
  }

  @override
  String get buyCredits => '购买积分';

  @override
  String get earnFreeCredits => '看广告赚取免费积分';

  @override
  String get rewardTitle => '获取免费积分';

  @override
  String rewardDescription(Object count) {
    return '观看短广告即可获得 $count 积分。积分将在将路线发送到车辆时使用。';
  }

  @override
  String get watchAd => '观看广告';

  @override
  String rewardEarned(Object count) {
    return '$count 积分已到账！';
  }

  @override
  String get creditsUpdated => '积分已更新。';

  @override
  String get rewardNotCompleted => '需要完整观看广告才能获得积分。';

  @override
  String get rewardAdLoadFailed => '当前无法加载广告，请稍后重试。';

  @override
  String get oneTimePurchaseRequiredMessage => '您已用完所有免费次数。购买后即可继续使用导航。';

  @override
  String get oneTimePurchaseActiveLabel => '您的购买已激活。';

  @override
  String get debugAccessTokenTitle => '调试：Tesla 访问令牌';

  @override
  String get debugAccessTokenCopy => '复制令牌';

  @override
  String get debugAccessTokenCopied => '访问令牌已复制到剪贴板。';

  @override
  String get debugAccessTokenRefresh => '刷新';

  @override
  String get debugAccessTokenRefreshed => '访问令牌已刷新。';

  @override
  String get debugAccessTokenEmpty => '请使用 Tesla 帐号登录后查看访问令牌。';

  @override
  String get themeSectionTitle => '外观设置';

  @override
  String get themeDarkLabel => '深色模式';

  @override
  String get themeLightLabel => '浅色模式';

  @override
  String get themeChangedMessage => '主题已更新。';

  @override
  String get networkErrorTitle => '网络连接错误';

  @override
  String get networkErrorMessage => '请检查您的互联网连接并重试。';

  @override
  String get retry => '重试';

  @override
  String get close => '关闭';

  @override
  String get termsOfUse => '使用条款';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get termsAndPrivacy => '条款 / 隐私';

  @override
  String get legalSectionTitle => '法律声明';

  @override
  String get rewardAdMustFinish => '要获得积分，必须将广告观看至结束。';
}
