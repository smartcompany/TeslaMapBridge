import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// Checks if an error is a network-related error
bool isNetworkError(dynamic error) {
  if (error == null) return false;

  final errorString = error.toString().toLowerCase();
  return errorString.contains('failed host lookup') ||
      errorString.contains('no address associated') ||
      errorString.contains('socketexception') ||
      errorString.contains('clientexception') ||
      errorString.contains('network is unreachable') ||
      errorString.contains('connection refused') ||
      errorString.contains('connection timed out') ||
      errorString.contains('network connection');
}

/// Shows a network error dialog with retry option
Future<bool?> showNetworkErrorDialog(
  BuildContext context, {
  String? customMessage,
  VoidCallback? onRetry,
}) {
  final loc = AppLocalizations.of(context)!;

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.wifi_off, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 8),
          Text(loc.networkErrorTitle),
        ],
      ),
      content: Text(customMessage ?? loc.networkErrorMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(loc.close),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(true);
            onRetry?.call();
          },
          child: Text(loc.retry),
        ),
      ],
    ),
  );
}
