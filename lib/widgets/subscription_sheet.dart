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

            final usageMessage = () {
              if (service.isSubscribed) {
                return loc.subscriptionActiveLabel;
              }

              if (quota > 0) {
                return loc.subscriptionUsageStatus(quota);
              }

              return loc.subscriptionRequiredMessage;
            }();

            final productDescription = () {
              if (service.isSubscribed) {
                return '${product?.description} (${product?.price})';
              }

              if (product != null) {
                return product.description;
              }

              return loc.subscriptionLoading;
            }();

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
                Text(
                  productDescription,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onPrimaryContainer,
                    ),
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
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(loc.subscriptionProcessing),
                            ],
                          )
                        : Text(
                            buttonLabel,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (!service.isSubscribed)
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.secondary,
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
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                ),
                              )
                            : Text(loc.subscriptionRestoreButton),
                      ),
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
              ],
            );
          },
        ),
      ),
    );
  }
}
