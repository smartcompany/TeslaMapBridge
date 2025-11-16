import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/purchase_mode.dart';
import '../services/subscription_service.dart';
import 'standard_purchase_section.dart';

class SubscriptionSheet extends StatelessWidget {
  const SubscriptionSheet({super.key, required this.quota});

  final int quota;

  Widget _buildRestoreButton(
    BuildContext context,
    SubscriptionService service,
  ) {
    if (service.purchaseMode != PurchaseMode.subscription) {
      return const SizedBox.shrink();
    }

    if (service.isSubscribed) {
      return const SizedBox.shrink();
    }

    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.secondary,
      ),
      onPressed: service.restoreInProgress
          ? null
          : () async {
              await service.restorePurchases();
            },
      child: service.restoreInProgress
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.secondary,
              ),
            )
          : Text(AppLocalizations.of(context)!.subscriptionRestoreButton),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
        child: Consumer<SubscriptionService>(
          builder: (context, service, _) {
            // Get product for subscription/one-time modes
            final product = service.currentNonCreditProduct;
            final isProcessing =
                service.purchaseState == SubscriptionPurchaseState.purchasing ||
                service.purchaseState == SubscriptionPurchaseState.loading;
            final canPurchase =
                !service.isSubscribed && !isProcessing && product != null;

            final usageMessage = () {
              if (service.isSubscribed) {
                return service.purchaseMode == PurchaseMode.subscription
                    ? loc.subscriptionActiveLabel
                    : loc.oneTimePurchaseActiveLabel;
              }

              if (quota > 0) {
                return loc.subscriptionUsageStatus(quota);
              }

              return service.purchaseMode == PurchaseMode.subscription
                  ? loc.subscriptionRequiredMessage
                  : loc.oneTimePurchaseRequiredMessage;
            }();

            final productDescription = () {
              if (service.isSubscribed) {
                return '${product?.description ?? ''} (${product?.price ?? ''})';
              }

              if (product != null) {
                return product.description;
              }

              return loc.subscriptionLoading;
            }();

            final buttonLabel = () {
              if (service.isSubscribed) {
                return service.purchaseMode == PurchaseMode.subscription
                    ? loc.subscriptionActiveLabel
                    : loc.oneTimePurchaseActiveLabel;
              }
              if (isProcessing) {
                return loc.subscriptionProcessing;
              }
              if (product != null) {
                final baseLabel =
                    service.purchaseMode == PurchaseMode.subscription
                    ? loc.subscriptionUpgradeButton
                    : loc.oneTimePurchaseButton;
                return '$baseLabel (${product.price})';
              }
              return loc.subscriptionLoading;
            }();

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.purchaseMode == PurchaseMode.creditPack
                      ? AppLocalizations.of(context)!.creditsSectionTitle
                      : AppLocalizations.of(context)!.subscriptionSectionTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(usageMessage),
                const SizedBox(height: 16),
                StandardPurchaseSection(
                  productDescription: productDescription,
                  buttonLabel: buttonLabel,
                  canPurchase: canPurchase,
                  isProcessing: isProcessing,
                  onPressed: () => service.buyPremium(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildRestoreButton(context, service),
                    const Spacer(),
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
                if (service.lastError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      loc.subscriptionErrorLabel(service.lastError!),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
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
