import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:tesla_map_bridge/services/tesla_auth_service.dart';

class UsageStatus {
  const UsageStatus({required this.userId, required this.quota});

  final String userId;
  final int quota;
}

class ConsumptionResult {
  const ConsumptionResult({
    required this.success,
    required this.status,
    this.errorMessage,
  });

  final bool success;
  final UsageStatus status;
  final String? errorMessage;
}

class UsageLimitService {
  UsageLimitService._({http.Client? client})
    : _client = client ?? http.Client();

  static final UsageLimitService shared = UsageLimitService._();

  UsageStatus? userStatus;

  final Uri _quotaUri = Uri.parse(
    '${TeslaAuthService.shared.apiBaseHost}/api/quota',
  );
  final http.Client _client;

  UsageStatus _parseStatus(Map<String, dynamic> body) {
    final userId = body['userId'] as String;
    final quota = (body['quota'] as num?)?.toInt() ?? 0;
    return UsageStatus(userId: userId, quota: quota);
  }

  Future<UsageStatus> fetchStatus({
    required String userId,
    required String accessToken,
  }) async {
    if (userId.isEmpty) {
      throw ArgumentError('userId cannot be empty');
    }

    if (accessToken.isEmpty) {
      throw ArgumentError('accessToken cannot be empty');
    }

    try {
      final response = await _client.get(
        _quotaUri.replace(queryParameters: {'userId': userId}),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode != 200) {
        debugPrint(
          '[UsageLimit] Failed to fetch quota: ${response.statusCode}',
        );
        final body = jsonDecode(response.body) as Map<String, dynamic>?;
        final message = body?['error'] as String?;
        throw UsageLimitException(
          message: message ?? 'Failed to fetch quota',
          statusCode: response.statusCode,
        );
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final status = _parseStatus(body);
      userStatus = status;
      return status;
    } catch (error) {
      if (error is UsageLimitException) rethrow;
      debugPrint('[UsageLimit] Error fetching quota: $error');
      throw UsageLimitException(message: error.toString());
    }
  }

  Future<ConsumptionResult> consume({
    required String userId,
    required String accessToken,
  }) async {
    if (userId.isEmpty) {
      throw ArgumentError('userId cannot be empty');
    }

    if (accessToken.isEmpty) {
      throw ArgumentError('accessToken cannot be empty');
    }

    try {
      final response = await _client.post(
        Uri.parse('${_quotaUri.toString()}/use'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'userId': userId}),
      );

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>?;
        final message = body?['error'] as String?;
        throw UsageLimitException(
          message: message ?? 'Failed to update quota',
          statusCode: response.statusCode,
        );
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final status = _parseStatus(body);
      userStatus = status;
      return ConsumptionResult(success: true, status: status);
    } on UsageLimitException catch (error) {
      debugPrint('[UsageLimit] consume failed: $error');
      return ConsumptionResult(
        success: false,
        status: UsageStatus(userId: userId, quota: 0),
        errorMessage: error.message,
      );
    }
  }

  Future<UsageStatus> addCredits(int credits) async {
    final userId = await TeslaAuthService.shared.getEmail();
    final accessToken = await TeslaAuthService.shared.getAccessToken();

    if (userId == null || userId.isEmpty) {
      throw UsageLimitException(message: 'Not signed in');
    }

    if (accessToken == null || accessToken.isEmpty) {
      throw UsageLimitException(message: 'Missing access token');
    }

    if (credits <= 0) {
      throw UsageLimitException(message: 'credits must be > 0');
    }

    final uri = Uri.parse('${_quotaUri.toString()}/add');
    final res = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'userId': userId, 'credits': credits}),
    );

    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>?;
      throw UsageLimitException(
        message: body?['error'] as String? ?? 'Failed to add credits',
      );
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final status = _parseStatus(body);
    userStatus = status;
    return status;
  }
}

class UsageLimitException implements Exception {
  UsageLimitException({required this.message, this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'UsageLimitException($statusCode): $message';
}
