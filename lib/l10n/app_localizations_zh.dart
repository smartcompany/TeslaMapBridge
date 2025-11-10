// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '特斯拉地图桥';

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
}
