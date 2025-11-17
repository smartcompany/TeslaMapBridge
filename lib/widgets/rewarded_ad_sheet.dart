import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/tesla_auth_service.dart';

class RewardedAdSheet extends StatelessWidget {
  const RewardedAdSheet({super.key, required this.onWatchPressed});

  final VoidCallback onWatchPressed;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final rewardCredits = TeslaAuthService.shared.getRewardCreditsPerAd();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.rewardTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(
              loc.rewardDescription(rewardCredits),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onWatchPressed();
                    },
                    child: Text(loc.watchAd),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(loc.cancel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
