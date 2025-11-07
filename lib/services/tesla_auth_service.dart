import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TeslaAuthService {
  static const _storage = FlutterSecureStorage();
  static const _accessTokenKey = 'tesla_access_token';
  static const _refreshTokenKey = 'tesla_refresh_token';
  static const _expiresAtKey = 'tesla_expires_at';
  static const _emailKey = 'tesla_email';
  static const _codeVerifierKey = 'tesla_code_verifier';

  // Tesla OAuth endpoints
  static const String _authBaseUrl = 'https://auth.tesla.com';
  static const String _ownerApiUrl = 'https://owner-api.teslamotors.com';
  static const String _redirectUri = 'https://auth.tesla.com/void/callback';

  // Tesla Fleet API Client Credentials
  // Tesla Developer Portal (https://developer.tesla.com/)에서 등록 후 발급받은 값으로 교체하세요
  static const String _clientId = '3a036053-105d-4f0b-b315-15e7b38e2df8';
  static const String _clientSecret = 'ta-secret.+rCpCXAHo1VSAT+b';

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    if (accessToken == null) return false;

    // Check if token is expired
    final expiresAtStr = await _storage.read(key: _expiresAtKey);
    if (expiresAtStr != null) {
      final expiresAt = DateTime.parse(expiresAtStr);
      if (DateTime.now().isAfter(expiresAt)) {
        // Try to refresh token
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

      final body = {
        'grant_type': 'authorization_code',
        'client_id': _clientId,
        'code': authorizationCode,
        'code_verifier': codeVerifier,
        'redirect_uri': _redirectUri,
      };

      // Add client_secret if it's set
      if (_clientSecret != 'YOUR_CLIENT_SECRET_HERE') {
        body['client_secret'] = _clientSecret;
      }

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

      final response = await http.get(
        Uri.parse('$_ownerApiUrl/api/1/users/me'),
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
      final refreshToken = await _storage.read(key: _refreshTokenKey);
      if (refreshToken == null) return false;

      final body = {
        'grant_type': 'refresh_token',
        'client_id': _clientId,
        'refresh_token': refreshToken,
      };

      // Add client_secret if it's set
      if (_clientSecret != 'YOUR_CLIENT_SECRET_HERE') {
        body['client_secret'] = _clientSecret;
      }

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
        final newRefreshToken =
            responseData['refresh_token'] as String? ?? refreshToken;
        final expiresIn = responseData['expires_in'] as int;

        // Update tokens
        await _storage.write(key: _accessTokenKey, value: accessToken);
        await _storage.write(key: _refreshTokenKey, value: newRefreshToken);

        // Update expiration time
        final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
        await _storage.write(
          key: _expiresAtKey,
          value: expiresAt.toIso8601String(),
        );

        return true;
      } else {
        print('Token refresh failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Token refresh error: $e');
      return false;
    }
  }

  /// Logout and clear stored tokens
  Future<void> logout() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _expiresAtKey);
    await _storage.delete(key: _emailKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_codeVerifierKey);
  }

  /// Get list of vehicles
  Future<List<Map<String, dynamic>>> getVehicles() async {
    try {
      final accessToken = await getAccessToken();
      if (accessToken == null) return [];

      if (!await isLoggedIn()) {
        return [];
      }

      final response = await http.get(
        Uri.parse('$_ownerApiUrl/api/1/vehicles'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['response'] ?? []);
      }

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
      final accessToken = await getAccessToken();
      if (accessToken == null) return false;

      if (!await isLoggedIn()) {
        return false;
      }

      final response = await http.post(
        Uri.parse('$_ownerApiUrl/api/1/vehicles/$vehicleId/command/share'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'type': 'share_ext_content_raw',
          'value': {
            'android.intent.ACTION_VIEW':
                'geo:$latitude,$longitude?q=$destinationName',
            'lat': latitude,
            'lon': longitude,
            'label': destinationName,
          },
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Send destination error: $e');
      return false;
    }
  }
}
