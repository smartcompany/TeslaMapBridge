/// Purchase mode type for in-app purchases
enum PurchaseMode {
  /// Subscription-based purchase (monthly/annual)
  subscription,

  /// One-time purchase
  oneTime,

  /// Consumable credit packs (buy usage counts)
  creditPack,
}

extension PurchaseModeExtension on PurchaseMode {
  /// Parse purchase mode from server response string
  static PurchaseMode? fromString(String? value) {
    final key = value?.toLowerCase();
    if (key == 'subscription') return PurchaseMode.subscription;
    if (key == 'onetime') return PurchaseMode.oneTime; // 'oneTime' -> 'onetime'
    if (key == 'creditpack') return PurchaseMode.creditPack; // 'creditPack'
    return null;
  }

  /// Convert to server-compatible string
  String toServerString() {
    switch (this) {
      case PurchaseMode.subscription:
        return 'subscription';
      case PurchaseMode.oneTime:
        return 'oneTime';
      case PurchaseMode.creditPack:
        return 'creditPack';
    }
  }
}
