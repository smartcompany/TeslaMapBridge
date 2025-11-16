import 'package:flutter/material.dart';
import '../services/subscription_service.dart';
import '../l10n/app_localizations.dart';

class CreditPackSection extends StatelessWidget {
  const CreditPackSection({
    super.key,
    required this.service,
    required this.isProcessing,
  });

  final SubscriptionService service;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Use products fetched from the store (already filtered/sorted in the service)
    final products = service.creditPackProducts;

    Widget pill(String text, {bool primary = false}) {
      final bg = primary
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceVariant.withOpacity(0.6);
      final fg = primary
          ? theme.colorScheme.onPrimaryContainer
          : theme.colorScheme.onSurfaceVariant;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(color: fg),
        ),
      );
    }

    // Baseline unit price (price per credit) from the smallest pack
    double? baselineUnitPrice() {
      final base = service.products.where((p) => p.id.endsWith('100'));
      if (base.isEmpty) return null;
      final raw = base.first.rawPrice;
      if (raw > 0) {
        return (raw as num).toDouble() / 100.0;
      }
      return null;
    }

    String? computedBenefitLabel({
      required int credits,
      required double? unitPriceBaseline,
      required double? rawPrice,
    }) {
      if (unitPriceBaseline == null || rawPrice == null) return null;
      final expected = unitPriceBaseline * credits;
      if (expected <= 0) return null;
      final benefit = ((expected - rawPrice) / expected) * 100.0;
      final percent = benefit.floor();
      if (percent <= 0) return null;
      return '+$percent% 혜택';
    }

    final unitBaseline = baselineUnitPrice();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        ...products.map((p) {
          // Infer credits from product id suffix (100/400/800/1000)
          int credits = 0;
          if (p.id.endsWith('1000'))
            credits = 1000;
          else if (p.id.endsWith('800'))
            credits = 800;
          else if (p.id.endsWith('400'))
            credits = 400;
          else if (p.id.endsWith('100'))
            credits = 100;
          final suffix = credits.toString();
          final title = '$credits credits';

          // Match product by id suffix to be resilient to full bundle prefix
          final matching = service.products.where(
            (it) => it.id.endsWith(suffix),
          );
          final hasProduct = matching.isNotEmpty;
          final priceText = hasProduct ? matching.first.price : '—';
          final rawPrice = hasProduct
              ? (matching.first.rawPrice as num?)?.toDouble()
              : null;
          final benefit = computedBenefitLabel(
            credits: credits,
            unitPriceBaseline: unitBaseline,
            rawPrice: rawPrice,
          );

          return Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.bolt),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (benefit != null)
                          Row(
                            children: [
                              pill(
                                // Localize benefit label
                                AppLocalizations.of(
                                  context,
                                )!.creditsBenefitLabel(
                                  int.tryParse(
                                        benefit.replaceAll(
                                          RegExp(r'[^0-9]'),
                                          '',
                                        ),
                                      ) ??
                                      0,
                                ),
                                primary: true,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 36,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2B2F36), // dark button
                        foregroundColor: Colors.white, // white label
                      ),
                      onPressed: isProcessing || !hasProduct
                          ? null
                          : () async {
                              await service.buyCredits(matching.first.id);
                            },
                      child: Text(
                        priceText,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
        const SizedBox(height: 8),
      ],
    );
  }
}
