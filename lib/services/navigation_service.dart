import 'package:url_launcher/url_launcher.dart';

const String kDefaultNavigationAppKey = 'default_navigation_app';

enum NavigationApp { tmap, naver, kakao }

class NavigationService {
  // Launch navigation app with destination
  Future<bool> launchNavigation(
    NavigationApp app,
    double lat,
    double lng,
    String? name,
  ) async {
    String url;

    switch (app) {
      case NavigationApp.tmap:
        // T Map URL scheme
        final placeName = name != null ? Uri.encodeComponent(name) : '';
        url = 'tmap://route?goalx=$lng&goaly=$lat&goalname=$placeName';
        break;

      case NavigationApp.naver:
        // 네이버 네비 URL scheme
        final placeName = name != null ? Uri.encodeComponent(name) : '';
        url = 'nmap://route?dlat=$lat&dlng=$lng&dname=$placeName';
        break;

      case NavigationApp.kakao:
        // 카카오 네비 URL scheme
        final placeName = name != null ? Uri.encodeComponent(name) : '';
        // Try kakaomap first, then kakaonavi
        url = 'kakaomap://route?ep=$lat,$lng&by=CAR&name=$placeName';
        break;
    }

    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback: try alternative schemes
      return await _tryAlternativeSchemes(app, lat, lng, name);
    }
  }

  Future<bool> _tryAlternativeSchemes(
    NavigationApp app,
    double lat,
    double lng,
    String? name,
  ) async {
    String url;
    final placeName = name != null ? Uri.encodeComponent(name) : '';

    switch (app) {
      case NavigationApp.tmap:
        // Try alternative T Map scheme
        url = 'tmap://search?name=$placeName&lon=$lng&lat=$lat';
        break;

      case NavigationApp.naver:
        // Try 네이버 지도 web URL
        url = 'https://map.naver.com/v5/directions/-/-/$lat,$lng';
        break;

      case NavigationApp.kakao:
        // Try kakaonavi alternative
        url = 'kakaonavi://navigate?name=$placeName&x=$lng&y=$lat';
        if (!await canLaunchUrl(Uri.parse(url))) {
          // Try 카카오맵 web URL as last resort
          url = 'https://map.kakao.com/link/to/$placeName,$lat,$lng';
        }
        break;
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    return false;
  }

  // Check if navigation app is installed
  Future<bool> isAppInstalled(NavigationApp app) async {
    String url;

    switch (app) {
      case NavigationApp.tmap:
        url = 'tmap://';
        break;
      case NavigationApp.naver:
        url = 'nmap://';
        break;
      case NavigationApp.kakao:
        url = 'kakaomap://';
        if (!await canLaunchUrl(Uri.parse(url))) {
          url = 'kakaonavi://';
        }
        break;
    }

    final uri = Uri.parse(url);
    return await canLaunchUrl(uri);
  }

  String getAppName(NavigationApp app) {
    switch (app) {
      case NavigationApp.tmap:
        return 'T맵';
      case NavigationApp.naver:
        return '네이버 네비';
      case NavigationApp.kakao:
        return '카카오 네비';
    }
  }
}
