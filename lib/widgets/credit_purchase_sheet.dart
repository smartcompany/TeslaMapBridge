import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../services/subscription_service.dart';
import '../services/usage_limit_service.dart';
import 'credit_pack_section.dart';

class CreditPurchaseSheet extends StatefulWidget {
  const CreditPurchaseSheet({super.key, required this.quota});

  final int quota;

  @override
  State<CreditPurchaseSheet> createState() => _CreditPurchaseSheetState();
}

class _CreditPurchaseSheetState extends State<CreditPurchaseSheet> {
  SubscriptionService? _subscriptionService;
  SubscriptionPurchaseState? _lastPurchaseState;
  String? _lastProcessingProductId;
  late int? _currentQuota;

  @override
  void initState() {
    super.initState();
    _currentQuota = UsageLimitService.shared.userStatus?.quota;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newService = Provider.of<SubscriptionService>(context, listen: false);
    if (_subscriptionService != newService) {
      _subscriptionService?.removeListener(_handleServiceUpdate);
      _subscriptionService = newService;
      _subscriptionService?.addListener(_handleServiceUpdate);
      _handleServiceUpdate();
    }
  }

  @override
  void dispose() {
    _subscriptionService?.removeListener(_handleServiceUpdate);
    super.dispose();
  }

  void _handleServiceUpdate() {
    final service = _subscriptionService;
    if (service == null || !mounted) return;

    final latestQuota = UsageLimitService.shared.userStatus?.quota;
    final purchaseState = service.purchaseState;
    final processingId = service.processingProductId;

    final shouldUpdateQuota =
        latestQuota != null && latestQuota != _currentQuota;
    final shouldUpdateState = purchaseState != _lastPurchaseState;
    final shouldUpdateProcessing = processingId != _lastProcessingProductId;

    if (!shouldUpdateQuota && !shouldUpdateState && !shouldUpdateProcessing) {
      return;
    }

    setState(() {
      if (latestQuota != null && latestQuota != _currentQuota) {
        _currentQuota = latestQuota;
      }
      _lastPurchaseState = purchaseState;
      _lastProcessingProductId = processingId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final service = _subscriptionService;
    if (service == null) {
      return const SizedBox.shrink();
    }

    final purchaseState = _lastPurchaseState ?? service.purchaseState;
    final isProcessing =
        service.processingProductId != null ||
        purchaseState == SubscriptionPurchaseState.loading;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 24, 12, 24 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.creditsSectionTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(
                    context,
                  )!.creditsOwnedLabel(_currentQuota ?? 0),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CreditPackSection(
              service: service,
              isProcessing: isProcessing,
              processingProductId: service.processingProductId,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(loc.cancel),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () async {
                    final url = Uri.parse(
                      'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
                    );
                    if (await canLaunchUrl(url)) {
                      await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  child: Text(
                    loc.termsOfUse,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(
                  ' • ',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final locale = Localizations.localeOf(context);
                    final baseUrl =
                        'https://smartcompany.github.io/TeslaMapBridge/privacy.html';
                    final url = Uri.parse(
                      locale.languageCode == 'ko' ? '$baseUrl#ko' : baseUrl,
                    );
                    if (await canLaunchUrl(url)) {
                      await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  child: Text(
                    loc.privacyPolicy,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
