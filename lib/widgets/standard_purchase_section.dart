import 'package:flutter/material.dart';

class StandardPurchaseSection extends StatelessWidget {
  const StandardPurchaseSection({
    super.key,
    required this.productDescription,
    required this.buttonLabel,
    required this.canPurchase,
    required this.isProcessing,
    required this.onPressed,
  });

  final String productDescription;
  final String buttonLabel;
  final bool canPurchase;
  final bool isProcessing;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          productDescription,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  Theme.of(context).colorScheme.primaryContainer,
              foregroundColor:
                  Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            onPressed: canPurchase ? () async => onPressed() : null,
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
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Processing...'),
                    ],
                  )
                : Text(
                    buttonLabel,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }
}


