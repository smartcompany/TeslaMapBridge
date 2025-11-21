import 'dart:convert';
import 'dart:math';
import 'dart:io' as io;
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/credit_pack_meta.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/purchase_mode.dart';

import '../models/tesla_navigation_mode.dart';

class TeslaAuthService {
  // Private constructor
  TeslaAuthService._();

  // Shared instance (Swift-style singleton)
  static final TeslaAuthService shared = TeslaAuthService._();

  static const _storage = FlutterSecureStorage();
  static const _accessTokenKey = 'tesla_access_token';
  static const _refreshTokenKey = 'tesla_refresh_token';
  static const _expiresAtKey = 'tesla_expires_at';
  static const _emailKey = 'tesla_email';
  static const _codeVerifierKey = 'tesla_code_verifier';
  static const _partnerAccessTokenKey = 'tesla_partner_access_token';
  static const _partnerExpiresAtKey = 'tesla_partner_expires_at';
  static const kTeslaNavigationModeKey = 'tesla_navigation_mode';
  static const _selectedVehicleIdKey = 'tesla_selected_vehicle_id';

  // Tesla OAuth endpoints
  static const String _authBaseUrl = 'https://auth.tesla.com';
  static const String _redirectUri = 'https://auth.tesla.com/void/callback';

  // Tesla Fleet API Client Credentials
  // Tesla Developer Portal (https://developer.tesla.com/)에서 등록 후 발급받은 값으로 교체하세요
  static const String _apiBaseUrlKey = 'tesla_api_base_url';
  final String apiBaseHost = 'https://tesla-map-bridge.vercel.app';
  String get _settingsEndpoint => '$apiBaseHost/api/settings';

  String? _clientId;
  String? _clientSecret;
  Map<String, CreditPackMeta> creditPackProductIdToCredits = const {};

  late String? adsType;
  late String? adsId;
  late int? rewardCreditsPerAd;

  PurchaseMode? currentPurchaseMode;

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    final storedRefreshToken = await _storage.read(key: _refreshTokenKey);

    if (storedRefreshToken == null && accessToken == null) {
      return false;
    }

    if (accessToken == null) {
      return await refreshToken();
    }

    // Check if token is expired (or close to expiring)
    final expiresAtStr = await _storage.read(key: _expiresAtKey);
    if (expiresAtStr != null) {
      final expiresAt = DateTime.parse(expiresAtStr);
      // Refresh one minute before expiry to avoid race conditions on API calls.
      if (DateTime.now().isAfter(
        expiresAt.subtract(const Duration(minutes: 1)),
      )) {
        return await refreshToken();
      }
    }

    return true;
  }

  /// Get stored access token
  Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  /// Get stored email
  Future<String?> getEmail() async {
    return await _storage.read(key: _emailKey);
  }

  Future<void> _clearPartnerAuthTokens() async {
    await _storage.delete(key: _partnerAccessTokenKey);
    await _storage.delete(key: _partnerExpiresAtKey);
  }

  Future<void> _storeFleetApiBaseUrl(Map<String, dynamic> responseData) async {
    try {
      final fleetUrl = _extractFleetAudience(responseData);
      if (fleetUrl != null && fleetUrl.isNotEmpty) {
        await _storage.write(key: _apiBaseUrlKey, value: fleetUrl);
      }
    } catch (e) {
      print('Failed to store fleet api base url: $e');
    }
  }

  Future<String?> getFleetAuthUrl() async {
    return await _storage.read(key: _apiBaseUrlKey);
  }

  String? resolve(dynamic candidate) {
    if (candidate is String && _isFleetUrl(candidate)) {
      return candidate;
    }
    if (candidate is List) {
      for (final value in candidate.whereType<String>()) {
        if (_isFleetUrl(value)) {
          return value;
        }
      }
    }
    return null;
  }

  String? _extractFleetAudience(Map<String, dynamic> responseData) {
    final directAudience = resolve(responseData['aud']);
    if (directAudience != null) {
      return directAudience;
    }

    final accessToken = responseData['access_token'] as String?;
    if (accessToken == null) return null;

    try {
      final parts = accessToken.split('.');
      if (parts.length < 2) return null;

      String normalize(String input) {
        final padding = (4 - input.length % 4) % 4;
        return input.padRight(input.length + padding, '=');
      }

      final payloadSegment = normalize(parts[1]);
      final payloadJson = utf8.decode(base64Url.decode(payloadSegment));
      final payloadMap = jsonDecode(payloadJson) as Map<String, dynamic>;
      return resolve(payloadMap['aud']);
    } catch (e) {
      print('Failed to decode access token audience: $e');
      return null;
    }
  }

  bool _isFleetUrl(String value) {
    return value.startsWith('https://fleet-api.') &&
        value.contains('.vn.cloud.tesla.com');
  }

  Future<Uri> _buildFleetUri(String path) async {
    final fleetAuthUrl = await getFleetAuthUrl();
    if (fleetAuthUrl == null || fleetAuthUrl.isEmpty) {
      print('[TeslaAuth] Fleet auth url not found');
      throw Exception('Fleet auth url not found');
    }

    if (fleetAuthUrl.endsWith('/') && path.startsWith('/')) {
      return Uri.parse('$fleetAuthUrl${path.substring(1)}');
    } else if (!fleetAuthUrl.endsWith('/') && !path.startsWith('/')) {
      return Uri.parse('$fleetAuthUrl/$path');
    }
    return Uri.parse('$fleetAuthUrl$path');
  }

  /// Force-refresh settings and return parsed purchase mode (if any)
  Future<bool> loadSettings() async {
    try {
      final uri = Uri.parse(_settingsEndpoint);
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        return false;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      currentPurchaseMode = PurchaseModeExtension.fromString(
        data['purchaseMode'] as String?,
      );

      _clientId = data['clientId'] as String?;
      _clientSecret = data['clientSecret'] as String?;

      final packs = data['creditPacks'];
      if (packs is List) {
        final map = <String, CreditPackMeta>{};
        for (final item in packs.whereType<Map<String, dynamic>>()) {
          final id = item['productId'] as String?;
          final credits = (item['credits'] as num?)?.toInt();
          if (id != null && id.isNotEmpty && credits != null && credits > 0) {
            // On Android, convert productId to lowercase for Google Play Console compatibility
            final normalizedId = io.Platform.isAndroid ? id.toLowerCase() : id;
            map[normalizedId] = CreditPackMeta(credits: credits);
          }
        }
        creditPackProductIdToCredits = map;
      }

      adsType = () {
        if (io.Platform.isIOS) {
          return data['ios_ad'] as String;
        } else if (io.Platform.isAndroid) {
          return data['android_ad'] as String;
        }
        return '';
      }();

      adsId = () {
        if (io.Platform.isIOS) {
          return data['ref']['ios'][adsType] as String;
        } else if (io.Platform.isAndroid) {
          return data['ref']['android'][adsType] as String;
        }
        return '';
      }();

      rewardCreditsPerAd = () {
        return data['adRewards'][adsType] as int;
      }();
    } catch (_) {
      return false;
    }
    return true;
  }

  Future<TeslaNavigationMode> getNavigationModePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(kTeslaNavigationModeKey);
    if (stored != null) {
      for (final mode in TeslaNavigationMode.values) {
        if (mode.name == stored) {
          return mode;
        }
      }
    }
    return TeslaNavigationMode.destination;
  }

  Future<void> setNavigationModePreference(TeslaNavigationMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kTeslaNavigationModeKey, mode.name);
  }

  Future<String?> getSelectedVehicleId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedVehicleIdKey);
  }

  Future<void> setSelectedVehicleId(String? vehicleId) async {
    final prefs = await SharedPreferences.getInstance();
    if (vehicleId == null || vehicleId.isEmpty) {
      await prefs.remove(_selectedVehicleIdKey);
    } else {
      await prefs.setString(_selectedVehicleIdKey, vehicleId);
    }
  }

  Future<String?> getPartnerAccessToken() async {
    final existingToken = await _storage.read(key: _partnerAccessTokenKey);
    final expiresAtStr = await _storage.read(key: _partnerExpiresAtKey);

    if (existingToken != null && expiresAtStr != null) {
      final expiresAt = DateTime.tryParse(expiresAtStr);
      if (expiresAt != null &&
          DateTime.now().isBefore(
            expiresAt.subtract(const Duration(minutes: 1)),
          )) {
        return existingToken;
      }
    }

    return await _requestPartnerAccessToken();
  }

  Future<String?> _requestPartnerAccessToken() async {
    try {
      if (_clientId == null || _clientSecret == null) {
        print('[TeslaAuth] Client credentials not loaded');
        return null;
      }

      final fleetAuthUrl = await getFleetAuthUrl();
      if (fleetAuthUrl == null || fleetAuthUrl.isEmpty) {
        print('[TeslaAuth] Fleet auth url not found');
        return null;
      }

      final formBody =
          {
                'grant_type': 'client_credentials',
                'client_id': _clientId!,
                'client_secret': _clientSecret!,
                'scope':
                    'openid vehicle_device_data vehicle_cmds vehicle_charging_cmds',
                'audience': fleetAuthUrl,
              }.entries
              .map(
                (entry) =>
                    '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
              )
              .join('&');

      final response = await http.post(
        Uri.parse('$fleetAuthUrl/oauth2/v3/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: formBody,
      );

      if (response.statusCode != 200) {
        print(
          '[TeslaAuth] Partner token request failed: '
          '${response.statusCode} ${response.body}',
        );
        return null;
      }

      final responseData = jsonDecode(response.body);
      final partnerAccessToken = responseData['access_token'] as String?;
      final expiresIn = responseData['expires_in'] as int?;

      if (partnerAccessToken == null || expiresIn == null) {
        print(
          '[TeslaAuth] Partner token response missing data: ${response.body}',
        );
        return null;
      }

      final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
      await _storage.write(
        key: _partnerAccessTokenKey,
        value: partnerAccessToken,
      );
      await _storage.write(
        key: _partnerExpiresAtKey,
        value: expiresAt.toIso8601String(),
      );

      return partnerAccessToken;
    } catch (e) {
      print('[TeslaAuth] Partner token request error: $e');
      return null;
    }
  }

  /// Generate PKCE code verifier and challenge
  Map<String, String> _generatePKCE() {
    // Generate code verifier (random string, 43-128 characters)
    final random = Random.secure();
    final verifierBytes = List<int>.generate(64, (i) => random.nextInt(256));
    final codeVerifier = base64UrlEncode(
      verifierBytes,
    ).replaceAll('=', '').replaceAll('+', '-').replaceAll('/', '_');

    // Generate code challenge (SHA256 hash of verifier, base64url encoded)
    final codeChallengeBytes = sha256.convert(utf8.encode(codeVerifier)).bytes;
    final codeChallenge = base64UrlEncode(
      codeChallengeBytes,
    ).replaceAll('=', '').replaceAll('+', '-').replaceAll('/', '_');

    return {'code_verifier': codeVerifier, 'code_challenge': codeChallenge};
  }

  /// Generate OAuth authorization URL with PKCE
  Future<String> getAuthorizationUrl() async {
    if (_clientId == null) {
      throw Exception('Client ID not loaded. Call loadSettings() first.');
    }

    final pkce = _generatePKCE();
    final codeVerifier = pkce['code_verifier']!;
    final codeChallenge = pkce['code_challenge']!;

    // Store code verifier for later use
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_codeVerifierKey, codeVerifier);

    final params = {
      'client_id': _clientId!,
      'redirect_uri': _redirectUri,
      'response_type': 'code',
      'scope':
          'openid email offline_access user_data vehicle_device_data vehicle_cmds vehicle_charging_cmds',
      'state': DateTime.now().millisecondsSinceEpoch.toString(),
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
    };

    final queryString = params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');

    return '$_authBaseUrl/oauth2/v3/authorize?$queryString';
  }

  /// Extract authorization code from redirect URL
  String? extractAuthorizationCode(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.queryParameters['code'];
    } catch (e) {
      print('Error extracting code: $e');
      return null;
    }
  }

  /// Exchange authorization code for access token with PKCE
  Future<bool> exchangeCodeForToken(String authorizationCode) async {
    try {
      if (_clientId == null || _clientSecret == null) {
        print('[TeslaAuth] Client credentials not loaded');
        return false;
      }

      // Get stored code verifier
      final prefs = await SharedPreferences.getInstance();
      final codeVerifier = prefs.getString(_codeVerifierKey);
      if (codeVerifier == null) {
        print('Code verifier not found');
        return false;
      }

      final body = {
        'grant_type': 'authorization_code',
        'client_id': _clientId!,
        'code': authorizationCode,
        'code_verifier': codeVerifier,
        'redirect_uri': _redirectUri,
      };

      body['client_secret'] = _clientSecret!;

      final formBody = body.entries
          .map(
            (e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
          )
          .join('&');

      final response = await http.post(
        Uri.parse('$_authBaseUrl/oauth2/v3/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: formBody,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final accessToken = responseData['access_token'] as String;
        final refreshToken = responseData['refresh_token'] as String;
        final expiresIn = responseData['expires_in'] as int;

        await _storeFleetApiBaseUrl(responseData);

        // Store tokens
        await _storage.write(key: _accessTokenKey, value: accessToken);
        await _storage.write(key: _refreshTokenKey, value: refreshToken);

        // Calculate expiration time
        final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
        await _storage.write(
          key: _expiresAtKey,
          value: expiresAt.toIso8601String(),
        );

        // Clear code verifier after successful exchange
        await prefs.remove(_codeVerifierKey);

        // Try to get user email from API
        await _storeUserEmail();

        return true;
      } else {
        print('Token exchange failed: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Token exchange error: $e');
      return false;
    }
  }

  /// Store user email from API
  Future<void> _storeUserEmail() async {
    try {
      final accessToken = await getAccessToken();
      if (accessToken == null) return;

      final usersMeUri = await _buildFleetUri('/api/1/users/me');
      final response = await http.get(
        usersMeUri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final email = data['response']?['email'] as String?;
        if (email != null) {
          await _storage.write(key: _emailKey, value: email);
        }
      }
    } catch (e) {
      print('Error storing user email: $e');
    }
  }

  /// Refresh access token using refresh token
  Future<bool> refreshToken() async {
    try {
      if (_clientId == null || _clientSecret == null) {
        print('[TeslaAuth] Client credentials not loaded');
        return false;
      }

      print('refreshToken = ${await _storage.read(key: _refreshTokenKey)}');
      print('accessToken = ${await _storage.read(key: _accessTokenKey)}');

      final refreshToken = await _storage.read(key: _refreshTokenKey);
      if (refreshToken == null) return false;

      final fleetAuthUrl = await getFleetAuthUrl();
      if (fleetAuthUrl == null || fleetAuthUrl.isEmpty) {
        print('[TeslaAuth] Fleet auth url not found');
        return false;
      }

      final body = {
        'grant_type': 'refresh_token',
        'client_id': _clientId!,
        'refresh_token': refreshToken,
        'audience': fleetAuthUrl,
      };

      body['client_secret'] = _clientSecret!;

      final formBody = body.entries
          .map(
            (e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
          )
          .join('&');

      final response = await http.post(
        Uri.parse('$_authBaseUrl/oauth2/v3/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: formBody,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final newAccessToken = responseData['access_token'] as String;
        final newRefreshToken = responseData['refresh_token'] as String;
        final expiresIn = responseData['expires_in'] as int;

        await _storeFleetApiBaseUrl(responseData);

        print('newAccessToken = $newAccessToken');
        print('newRefreshToken = $newRefreshToken');
        print('expiresIn = $expiresIn');

        // Update tokens
        await _storage.write(key: _accessTokenKey, value: newAccessToken);
        await _storage.write(key: _refreshTokenKey, value: newRefreshToken);

        // Update expiration time
        final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
        await _storage.write(
          key: _expiresAtKey,
          value: expiresAt.toIso8601String(),
        );

        return true;
      } else {
        print(
          '[TeslaAuth] Token refresh failed: ${response.statusCode} '
          '${response.body}',
        );
        return false;
      }
    } catch (e) {
      print('[TeslaAuth] Token refresh error: $e');
      return false;
    }
  }

  /// Logout and clear stored tokens
  Future<void> logout() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _expiresAtKey);
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _apiBaseUrlKey);
    await _clearPartnerAuthTokens();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_codeVerifierKey);
    try {
      final cookieManager = WebViewCookieManager();
      await cookieManager.clearCookies();
    } catch (e) {
      // Ignore cookie clearing errors; they shouldn't block logout.
      print('Error clearing webview cookies: $e');
    }
  }

  /// Get list of vehicles
  Future<List<Map<String, dynamic>>> getVehicles() async {
    try {
      if (!await isLoggedIn()) {
        return [];
      }

      final accessToken = await getAccessToken();
      if (accessToken == null) return [];

      Future<http.Response> makeRequest(String token) async {
        final vehiclesUri = await _buildFleetUri('/api/1/vehicles');
        return http.get(
          vehiclesUri,
          headers: {'Authorization': 'Bearer $token'},
        );
      }

      var tokenToUse = accessToken;
      var response = await makeRequest(tokenToUse);

      print('Get vehicles response: ${response.statusCode} ${response.body}');
      if (response.statusCode != 200) {
        final refreshed = await refreshToken();
        if (!refreshed) {
          print('[TeslaAuth] 401 when fetching vehicles and refresh failed.');
          return [];
        }
        final newAccessToken = await getAccessToken();
        if (newAccessToken == null) {
          print(
            '[TeslaAuth] 401 when fetching vehicles and refreshed token null.',
          );
          return [];
        }
        tokenToUse = newAccessToken;
        response = await makeRequest(tokenToUse);
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['response'] ?? []);
      }

      print('Get vehicles error: ${response.statusCode} ${response.body}');

      return [];
    } catch (e) {
      print('Get vehicles error: $e');
      return [];
    }
  }

  Future<bool> makeNavigationRequest(
    String token,
    String vehicleId,
    String destinationName,
    double latitude,
    double longitude, {
    String? destinationAddress,
  }) async {
    final navigationUri = await _buildFleetUri(
      '/api/1/vehicles/$vehicleId/command/navigation_request',
    );

    final localeTag = ui.PlatformDispatcher.instance.locale.toLanguageTag();

    // Combine address and name for better navigation accuracy
    // Format: "address, name" if both available, otherwise use available one
    final textValue = () {
      final address = destinationAddress?.trim() ?? '';
      final name = destinationName.trim();
      return '$name, $address, ($latitude,$longitude)';
    }();

    print('textValue = $textValue');

    final response = await http.post(
      navigationUri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'type': 'share_ext_content_raw',
        'value': {
          'android.intent.ACTION': 'android.intent.action.SEND',
          'android.intent.TYPE': 'text/plain',
          'android.intent.TEXT': textValue,
          'android.intent.extra.TEXT': textValue,
        },
        'locale': localeTag,
        'timestamp_ms': DateTime.now().millisecondsSinceEpoch.toString(),
      }),
    );

    final success = response.statusCode == 200 || response.statusCode == 202;
    if (!success) {
      print(
        '[TeslaNav] navigation_request failed '
        'status=${response.statusCode} body=${response.body}',
      );

      // Log to Firebase Crashlytics as non-fatal error
      try {
        // Set custom keys for this error
        await FirebaseCrashlytics.instance.setCustomKey(
          'navigation_request_status',
          response.statusCode,
        );
        await FirebaseCrashlytics.instance.setCustomKey(
          'navigation_request_destination_address',
          destinationAddress ?? 'N/A',
        );
        await FirebaseCrashlytics.instance.setCustomKey(
          'navigation_request_destination_name',
          destinationName,
        );
        await FirebaseCrashlytics.instance.setCustomKey(
          'navigation_request_latitude',
          latitude,
        );
        await FirebaseCrashlytics.instance.setCustomKey(
          'navigation_request_longitude',
          longitude,
        );
        await FirebaseCrashlytics.instance.setCustomKey(
          'navigation_request_text_value',
          textValue,
        );
        await FirebaseCrashlytics.instance.setCustomKey(
          'navigation_request_locale_tag',
          localeTag,
        );
        await FirebaseCrashlytics.instance.setCustomKey(
          'navigation_request_vehicle_id',
          vehicleId,
        );
        await FirebaseCrashlytics.instance.setCustomKey(
          'navigation_request_response_body',
          response.body,
        );

        // Record as non-fatal error so it appears immediately in Firebase Console
        await FirebaseCrashlytics.instance.recordError(
          Exception(
            'Tesla navigation_request failed: status=${response.statusCode}',
          ),
          StackTrace.current,
          reason: 'Navigation request failed',
          information: [
            'Destination Address: ${destinationAddress ?? "N/A"}',
            'Destination Name: $destinationName',
            'Latitude: $latitude',
            'Longitude: $longitude',
            'Text Value: $textValue',
            'Locale Tag: $localeTag',
            'Vehicle ID: $vehicleId',
            'Response Body: ${response.body}',
          ],
          fatal: false, // Non-fatal error
        );
      } catch (e) {
        print('[TeslaNav] Failed to log to Firebase: $e');
      }

      return false;
    }

    print('[TeslaNav] navigation_request success.');
    return true;
  }

  Future<bool> makeNavigationGpsRequest({
    required String vehicleId,
    required double latitude,
    required double longitude,
    int order = 1,
  }) async {
    try {
      if (!await isLoggedIn()) {
        print('[TeslaGPS] not logged in when trying to send GPS request.');
        return false;
      }

      final accessToken = await getAccessToken();
      if (accessToken == null) {
        print('[TeslaGPS] access token missing after login check.');
        return false;
      }

      Future<http.Response> makeRequest(String token) async {
        final gpsUri = await _buildFleetUri(
          '/api/1/vehicles/$vehicleId/command/navigation_gps_request',
        );
        return http.post(
          gpsUri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'lat': latitude, 'lon': longitude, 'order': order}),
        );
      }

      var tokenToUse = accessToken;
      var response = await makeRequest(tokenToUse);

      if (response.statusCode == 401) {
        final refreshed = await refreshToken();
        if (!refreshed) {
          print('[TeslaNav] 401 when sending GPS request and refresh failed.');
          return false;
        }
        final newAccessToken = await getAccessToken();
        if (newAccessToken == null) {
          print('[TeslaNav] Refreshed token was null after 401 (GPS request).');
          return false;
        }
        tokenToUse = newAccessToken;
        response = await makeRequest(tokenToUse);
      }

      final success = response.statusCode == 200 || response.statusCode == 202;
      if (!success) {
        print(
          '[TeslaNav] navigation_gps_request failed '
          'status=${response.statusCode} body=${response.body}',
        );
      } else {
        print('[TeslaNav] navigation_gps_request success.');
      }
      return success;
    } catch (e) {
      print('[TeslaNav] navigation_gps_request error: $e');
      return false;
    }
  }

  /// Send destination to a Tesla vehicle
  Future<bool> sendDestinationToVehicle(
    String vehicleId,
    double latitude,
    double longitude,
    String destinationName, {
    TeslaNavigationMode mode = TeslaNavigationMode.destination,
    String? destinationAddress,
  }) async {
    try {
      if (!await isLoggedIn()) {
        print('[TeslaSend] not logged in when trying to send destination.');
        return false;
      }

      final accessToken = await getAccessToken();
      if (accessToken == null) {
        print('[TeslaSend] access token missing after login check.');
        return false;
      }

      print(
        '[TeslaSend] Sending to vehicle=$vehicleId '
        'lat=$latitude lon=$longitude name=$destinationName '
        'address=${destinationAddress ?? "N/A"}',
      );

      if (mode == TeslaNavigationMode.gps) {
        return await makeNavigationGpsRequest(
          vehicleId: vehicleId,
          latitude: latitude,
          longitude: longitude,
        );
      }

      return await makeNavigationRequest(
        accessToken,
        vehicleId,
        destinationName,
        latitude,
        longitude,
        destinationAddress: destinationAddress,
      );
    } catch (e) {
      print('[TeslaSend] Send destination error: $e');
      return false;
    }
  }
}
