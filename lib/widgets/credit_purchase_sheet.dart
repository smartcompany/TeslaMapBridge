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
  late int _currentQuota;
  late final VoidCallback _usageStatusListener;

  @override
  void initState() {
    super.initState();
    _currentQuota = UsageLimitService.userStatus?.quota ?? widget.quota;
    _usageStatusListener = _handleUsageStatusChanged;
    UsageLimitService.userStatusNotifier.addListener(_usageStatusListener);
  }

  @override
  void dispose() {
    UsageLimitService.userStatusNotifier.removeListener(_usageStatusListener);
    super.dispose();
  }

  void _handleUsageStatusChanged() {
    final status = UsageLimitService.userStatus;
    if (!mounted || status == null) return;
    if (status.quota != _currentQuota) {
      setState(() {
        _currentQuota = status.quota;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final service = context.watch<SubscriptionService>();

    final purchaseState = service.purchaseState;
    final isProcessing =
        purchaseState == SubscriptionPurchaseState.purchasing ||
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
                  )!.creditsOwnedLabel(_currentQuota),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CreditPackSection(service: service, isProcessing: isProcessing),
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
