import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/subscription_service.dart';

class SubscriptionSheet extends StatelessWidget {
  const SubscriptionSheet({super.key, required this.quota});

  final int quota;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
        child: Consumer<SubscriptionService>(
          builder: (context, service, _) {
            final product = service.products.isNotEmpty
                ? service.products.first
                : null;
            final isProcessing =
                service.purchaseState == SubscriptionPurchaseState.purchasing ||
                service.purchaseState == SubscriptionPurchaseState.loading;
            final canPurchase =
                !service.isSubscribed && !isProcessing && product != null;

            final usageMessage = quota > 0 && !service.isSubscribed
                ? loc.subscriptionUsageStatus(quota)
                : loc.subscriptionRequiredMessage;

            final buttonLabel = () {
              if (service.isSubscribed) {
                return loc.subscriptionActiveLabel;
              }
              if (isProcessing) {
                return loc.subscriptionProcessing;
              }
              if (product != null) {
                return '${loc.subscriptionUpgradeButton} (${product.price})';
              }
              return loc.subscriptionLoading;
            }();

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.subscriptionSectionTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(usageMessage),
                const SizedBox(height: 16),
                if (service.isSubscribed)
                  Text(
                    loc.subscriptionActiveLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else if (product != null)
                  Text(
                    product.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else
                  Text(loc.subscriptionLoading),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: canPurchase
                      ? () async {
                          await service.buyMonthlyPremium();
                        }
                      : null,
                  child: isProcessing
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(loc.subscriptionProcessing),
                          ],
                        )
                      : Text(buttonLabel),
                ),
                const SizedBox(height: 12),
                if (!service.isSubscribed)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
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
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            )
                          : Text(loc.subscriptionRestoreButton),
                    ),
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
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(loc.cancel),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
