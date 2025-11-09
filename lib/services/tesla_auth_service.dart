import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TeslaAuthService {
  static const _storage = FlutterSecureStorage();
  static const _accessTokenKey = 'tesla_access_token';
  static const _refreshTokenKey = 'tesla_refresh_token';
  static const _expiresAtKey = 'tesla_expires_at';
  static const _emailKey = 'tesla_email';
  static const _codeVerifierKey = 'tesla_code_verifier';
  static const _partnerAccessTokenKey = 'tesla_partner_access_token';
  static const _partnerExpiresAtKey = 'tesla_partner_expires_at';

  // Tesla OAuth endpoints
  static const String _authBaseUrl = 'https://auth.tesla.com';
  static const String _defaultFleetApiUrl =
      'https://fleet-api.prd.na.vn.cloud.tesla.com';
  static const String _redirectUri = 'https://auth.tesla.com/void/callback';
  static const String _fleetAuthBaseUrl =
      'https://fleet-auth.prd.na.vn.cloud.tesla.com';

  // Tesla Fleet API Client Credentials
  // Tesla Developer Portal (https://developer.tesla.com/)에서 등록 후 발급받은 값으로 교체하세요
  static const String _clientId = '3a036053-105d-4f0b-b315-15e7b38e2df8';
  static const String _clientSecret = 'ta-secret.+rCpCXAHo1VSAT+b';
  static const String _apiBaseUrlKey = 'tesla_api_base_url';

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

  Future<String> _getFleetApiBaseUrl() async {
    return await _storage.read(key: _apiBaseUrlKey) ?? _defaultFleetApiUrl;
  }

  Future<Uri> _buildFleetUri(String path) async {
    final baseUrl = await _getFleetApiBaseUrl();
    if (baseUrl.endsWith('/') && path.startsWith('/')) {
      return Uri.parse('$baseUrl${path.substring(1)}');
    } else if (!baseUrl.endsWith('/') && !path.startsWith('/')) {
      return Uri.parse('$baseUrl/$path');
    }
    return Uri.parse('$baseUrl$path');
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
      final fleetBaseUrl = await _getFleetApiBaseUrl();
      final formBody =
          {
                'grant_type': 'client_credentials',
                'client_id': _clientId,
                'client_secret': _clientSecret,
                'scope':
                    'openid vehicle_device_data vehicle_cmds vehicle_charging_cmds',
                'audience': fleetBaseUrl,
              }.entries
              .map(
                (entry) =>
                    '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
              )
              .join('&');

      final response = await http.post(
        Uri.parse('$_fleetAuthBaseUrl/oauth2/v3/token'),
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

  Future<bool> registerPartnerAccount(String domain) async {
    try {
      final partnerToken = await getPartnerAccessToken();
      if (partnerToken == null) {
        print(
          '[TeslaAuth] Cannot register partner account: partner token null',
        );
        return false;
      }

      final registerUri = await _buildFleetUri('/api/1/partner_accounts');
      final response = await http.post(
        registerUri,
        headers: {
          'Authorization': 'Bearer $partnerToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'domain': domain}),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204 ||
          response.statusCode == 409) {
        // 409: 이미 등록된 경우.
        return true;
      }

      print(
        '[TeslaAuth] Partner account registration failed: '
        '${response.statusCode} ${response.body}',
      );
      return false;
    } catch (e) {
      print('[TeslaAuth] Partner account registration error: $e');
      return false;
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
    if (_clientId == 'YOUR_CLIENT_ID_HERE') {
      throw Exception(
        'Client ID가 설정되지 않았습니다. lib/services/tesla_auth_service.dart에서 _clientId를 설정하세요.',
      );
    }

    final pkce = _generatePKCE();
    final codeVerifier = pkce['code_verifier']!;
    final codeChallenge = pkce['code_challenge']!;

    // Store code verifier for later use
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_codeVerifierKey, codeVerifier);

    final params = {
      'client_id': _clientId,
      'redirect_uri': _redirectUri,
      'response_type': 'code',
      'scope':
          'openid offline_access user_data vehicle_device_data vehicle_cmds vehicle_charging_cmds',
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
      // Get stored code verifier
      final prefs = await SharedPreferences.getInstance();
      final codeVerifier = prefs.getString(_codeVerifierKey);
      if (codeVerifier == null) {
        print('Code verifier not found');
        return false;
      }

      final fleetAudience = await _getFleetApiBaseUrl();

      final body = {
        'grant_type': 'authorization_code',
        'client_id': _clientId,
        'code': authorizationCode,
        'code_verifier': codeVerifier,
        'redirect_uri': _redirectUri,
        'audience': fleetAudience,
      };

      body['client_secret'] = _clientSecret;

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
      print('refreshToken = ${await _storage.read(key: _refreshTokenKey)}');
      print('accessToken = ${await _storage.read(key: _accessTokenKey)}');

      final refreshToken = await _storage.read(key: _refreshTokenKey);
      if (refreshToken == null) return false;

      final fleetAudience = await _getFleetApiBaseUrl();

      final body = {
        'grant_type': 'refresh_token',
        'client_id': _clientId,
        'refresh_token': refreshToken,
        'audience': fleetAudience,
      };

      body['client_secret'] = _clientSecret;

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

  /// Send destination to a Tesla vehicle
  Future<bool> sendDestinationToVehicle(
    String vehicleId,
    double latitude,
    double longitude,
    String destinationName,
  ) async {
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
        'lat=$latitude lon=$longitude name=$destinationName',
      );

      Future<http.Response> makeRequest(String token) async {
        final shareUri = await _buildFleetUri(
          '/api/1/vehicles/$vehicleId/command/share',
        );
        final encodedName = Uri.encodeComponent(destinationName);
        final localeTag = ui.PlatformDispatcher.instance.locale.toLanguageTag();
        final navQuery = 'google.navigation:q=$latitude,$longitude';
        final geoUri = 'geo:$latitude,$longitude?q=$encodedName';

        return http.post(
          shareUri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'type': 'share_ext_content_raw',
            'value': {
              'locale': localeTag,
              'subject': destinationName,
              'title': destinationName,
              'text': destinationName,
              'type': 'text/plain',
              'android.intent.action': 'android.intent.action.VIEW',
              'android.intent.data': navQuery,
              'android.intent.extra.SUBJECT': destinationName,
              'android.intent.extra.TEXT': navQuery,
              'android.intent.extra.TITLE': destinationName,
              'android.intent.extra.MAP_URL': geoUri,
              'content': {
                'name': destinationName,
                'lat': latitude,
                'lon': longitude,
                'label': destinationName,
              },
            },
          }),
        );
      }

      var tokenToUse = accessToken;
      var response = await makeRequest(tokenToUse);

      if (response.statusCode == 401) {
        final refreshed = await refreshToken();
        if (!refreshed) {
          print('[TeslaSend] 401 when sending destination and refresh failed.');
          return false;
        }
        final newAccessToken = await getAccessToken();
        if (newAccessToken == null) {
          print('[TeslaSend] Refreshed token was null after 401.');
          return false;
        }
        tokenToUse = newAccessToken;
        response = await makeRequest(tokenToUse);
      }

      final success = response.statusCode == 200 || response.statusCode == 202;
      if (!success) {
        print(
          '[TeslaSend] command/share failed '
          'status=${response.statusCode} body=${response.body}',
        );
      } else {
        print('[TeslaSend] command/share success.');
      }
      return success;
    } catch (e) {
      print('[TeslaSend] Send destination error: $e');
      return false;
    }
  }
}
