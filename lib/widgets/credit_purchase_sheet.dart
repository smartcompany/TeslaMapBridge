import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../services/subscription_service.dart';
import 'credit_pack_section.dart';

class CreditPurchaseSheet extends StatelessWidget {
  const CreditPurchaseSheet({super.key, required this.quota});

  final int quota;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 24, 12, 24 + bottomInset),
        child: Consumer<SubscriptionService>(
          builder: (context, service, _) {
            final isProcessing =
                service.purchaseState == SubscriptionPurchaseState.purchasing ||
                service.purchaseState == SubscriptionPurchaseState.loading;

            final usageMessage = quota > 0
                ? loc.subscriptionUsageStatus(quota)
                : '';

            final currentCredits = quota * 2; // 2 credits per use

            return Column(
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
                    if (usageMessage.isNotEmpty) Text(usageMessage),
                    Text(
                      AppLocalizations.of(
                        context,
                      )!.creditsOwnedLabel(currentCredits),
                      style: Theme.of(context).textTheme.bodyMedium,
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
            );
          },
        ),
      ),
    );
  }
}
