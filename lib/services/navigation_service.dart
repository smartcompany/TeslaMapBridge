import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';

const String kDefaultNavigationAppKey = 'default_navigation_app';

enum NavigationApp {
  tmap,
  naver,
  kakao,
  googleMaps,
  waze,
  baiduMaps,
  gaodeMaps,
  tencentMaps,
  yahooCarNavi,
  navitime,
}

class NavigationService {
  // Launch navigation app with destination
  Future<bool> launchNavigation(
    NavigationApp app,
    double lat,
    double lng,
    String? name,
  ) async {
    final urls = _buildNavigationUrls(app, lat, lng, name);
    for (final url in urls) {
      if (await _launchUrl(url)) {
        return true;
      }
    }
    return false;
  }

  List<String> _buildNavigationUrls(
    NavigationApp app,
    double lat,
    double lng,
    String? name,
  ) {
    final encodedName = name != null ? Uri.encodeComponent(name) : '';
    switch (app) {
      case NavigationApp.tmap:
        return [
          'tmap://route?goalx=$lng&goaly=$lat&goalname=$encodedName',
          'tmap://search?name=$encodedName&lon=$lng&lat=$lat',
        ];
      case NavigationApp.naver:
        return [
          'nmap://route?dlat=$lat&dlng=$lng&dname=$encodedName',
          'https://map.naver.com/v5/directions/-/-/$lat,$lng',
        ];
      case NavigationApp.kakao:
        return [
          'kakaomap://route?ep=$lat,$lng&by=CAR&name=$encodedName',
          'kakaonavi://navigate?name=$encodedName&x=$lng&y=$lat',
          'https://map.kakao.com/link/to/$encodedName,$lat,$lng',
        ];
      case NavigationApp.googleMaps:
        return [
          if (Platform.isAndroid) 'google.navigation:q=$lat,$lng&mode=d',
          if (Platform.isIOS)
            'comgooglemaps://?daddr=$lat,$lng&directionsmode=driving',
          'geo:$lat,$lng?q=$encodedName',
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
        ];
      case NavigationApp.waze:
        return [
          'waze://?ll=$lat,$lng&navigate=yes',
          'https://waze.com/ul?ll=$lat,$lng&navigate=yes',
        ];
      case NavigationApp.baiduMaps:
        return [
          'baidumap://map/direction?destination=latlng:$lat,$lng|name:$encodedName&mode=driving&src=TeslaMapBridge',
          'http://api.map.baidu.com/direction?destination=$lat,$lng&mode=driving&output=html&src=TeslaMapBridge',
        ];
      case NavigationApp.gaodeMaps:
        final iosUrl =
            'iosamap://path?sourceApplication=TeslaMapBridge&dlat=$lat&dlon=$lng&dname=$encodedName&t=0';
        final androidUrl =
            'androidamap://route?sourceApplication=TeslaMapBridge&dlat=$lat&dlon=$lng&dname=$encodedName&dev=0&t=0';
        return [
          if (Platform.isIOS) iosUrl else androidUrl,
          'amapuri://route/plan/?dlat=$lat&dlon=$lng&dname=$encodedName&dev=0&t=0',
          'https://uri.amap.com/navigation?to=$lng,$lat,$encodedName&mode=car&src=TeslaMapBridge',
        ];
      case NavigationApp.tencentMaps:
        return [
          'qqmap://map/routeplan?type=drive&tocoord=$lat,$lng&to=$encodedName&referer=TeslaMapBridge',
          'https://apis.map.qq.com/uri/v1/routeplan?type=drive&tocoord=$lat,$lng&to=$encodedName&referer=TeslaMapBridge',
        ];
      case NavigationApp.yahooCarNavi:
        return [
          'yjnav://navigate?to=$lat,$lng&name=$encodedName',
          'https://map.yahoo.co.jp/dd/?lat=$lat&lon=$lng&mode=drive&title=$encodedName',
        ];
      case NavigationApp.navitime:
        return [
          'navitime://driveSearch?to=$lat,$lng&name=$encodedName',
          'https://www.navitime.co.jp/drive/?to=$lng,$lat&name=$encodedName',
        ];
    }
  }

  Future<bool> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await canLaunchUrl(uri)) {
      return false;
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // Check if navigation app is installed
  Future<bool> isAppInstalled(NavigationApp app) async {
    final schemes = <String>[..._preferredSchemes[app] ?? const []];
    for (final scheme in schemes) {
      final uri = Uri.parse(scheme);
      if (await canLaunchUrl(uri)) {
        return true;
      }
    }
    return false;
  }

  String getAppName(BuildContext context, NavigationApp app) {
    final loc = AppLocalizations.of(context)!;
    switch (app) {
      case NavigationApp.tmap:
        return loc.navAppTmap;
      case NavigationApp.naver:
        return loc.navAppNaver;
      case NavigationApp.kakao:
        return loc.navAppKakao;
      case NavigationApp.googleMaps:
        return loc.navAppGoogleMaps;
      case NavigationApp.waze:
        return loc.navAppWaze;
      case NavigationApp.baiduMaps:
        return loc.navAppBaiduMaps;
      case NavigationApp.gaodeMaps:
        return loc.navAppGaodeMaps;
      case NavigationApp.tencentMaps:
        return loc.navAppTencentMaps;
      case NavigationApp.yahooCarNavi:
        return loc.navAppYahooCarNavi;
      case NavigationApp.navitime:
        return loc.navAppNavitime;
    }
  }
}

const Map<NavigationApp, List<String>> _preferredSchemes = {
  NavigationApp.tmap: ['tmap://'],
  NavigationApp.naver: ['nmap://'],
  NavigationApp.kakao: ['kakaomap://', 'kakaonavi://'],
  NavigationApp.googleMaps: ['google.navigation:', 'comgooglemaps://', 'geo:'],
  NavigationApp.waze: ['waze://'],
  NavigationApp.baiduMaps: ['baidumap://'],
  NavigationApp.gaodeMaps: ['androidamap://', 'iosamap://', 'amapuri://'],
  NavigationApp.tencentMaps: ['qqmap://'],
  NavigationApp.yahooCarNavi: ['yjnav://', 'yjcnav://'],
  NavigationApp.navitime: ['navitime://'],
};
