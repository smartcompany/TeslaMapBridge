import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/subscription_service.dart';
import '../l10n/app_localizations.dart';

class CreditPackSection extends StatelessWidget {
  const CreditPackSection({
    super.key,
    required this.service,
    required this.isProcessing,
    this.processingProductId,
  });

  final SubscriptionService service;
  final bool isProcessing;
  final String? processingProductId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
      // base 는 creditPack 에서 가장 낮은 가격의 크레딧 팩
      final base = service.creditPacks.values.reduce((a, b) {
        final aPrice = a.rawPrice ?? 0.0;
        final bPrice = b.rawPrice ?? 0.0;
        if (aPrice < bPrice) {
          return a;
        } else {
          return b;
        }
      });

      // 크레딧당 단가 계산 (전체 가격 / 크레딧 수)
      if (base.rawPrice == null || base.rawPrice! <= 0 || base.credits <= 0) {
        return null;
      }
      return base.rawPrice! / base.credits;
    }

    int? computedBenefitLabel({
      required int credits,
      required double? unitPriceBaseline,
      required double? rawPrice,
    }) {
      // 가격 정보가 없으면 혜택 계산 불가
      if (unitPriceBaseline == null ||
          unitPriceBaseline <= 0 ||
          rawPrice == null ||
          rawPrice <= 0) {
        return null;
      }

      // 기준 단가로 계산한 예상 가격
      final expected = unitPriceBaseline * credits;
      if (expected <= 0) return null;

      // 예상 가격보다 실제 가격이 더 비싸면 혜택 없음
      if (rawPrice >= expected) return null;

      // 혜택 퍼센트 계산: (예상가격 - 실제가격) / 예상가격 * 100
      final benefit = ((expected - rawPrice) / expected) * 100.0;
      final percent = benefit.floor();
      if (percent <= 0) return null;

      return percent;
    }

    final unitBaseline = baselineUnitPrice();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        ...service.creditPacks.entries.map((entry) {
          final productId = entry.key;
          final p = entry.value;
          // Infer credits from product id suffix (100/400/800/1000)
          int credits = 0;
          credits = p.credits;
          final title = '${p.credits} credits';

          final priceText = p.displayPrice ?? '—';
          final rawPrice = p.rawPrice ?? 0.0;
          final benefit = computedBenefitLabel(
            credits: credits,
            unitPriceBaseline: unitBaseline,
            rawPrice: rawPrice,
          );

          // Check if product exists in IAP products list
          final hasProduct =
              service.products.any((prod) => prod.id == productId) &&
              priceText != '—';

          if (kDebugMode && !hasProduct) {
            debugPrint(
              '[CreditPack] Product not available: $productId, priceText: $priceText',
            );
            debugPrint(
              '[CreditPack] Available products: ${service.products.map((p) => p.id).join(", ")}',
            );
          }

          final isCurrentProcessing =
              isProcessing && processingProductId == productId;

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
                                )!.creditsBenefitLabel(benefit),
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
                              await service.buyCredits(productId);
                            },
                      child: isCurrentProcessing
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  priceText,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            )
                          : Text(
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
