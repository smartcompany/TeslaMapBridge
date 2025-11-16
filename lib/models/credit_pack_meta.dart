class CreditPackMeta {
  CreditPackMeta({
    required this.credits,
    this.rawPrice,
    this.displayPrice,
  });

  final int credits;
  double? rawPrice; // e.g., 0.99
  String? displayPrice; // e.g., US$0.99

  CreditPackMeta copyWith({
    int? credits,
    double? rawPrice,
    String? displayPrice,
  }) {
    return CreditPackMeta(
      credits: credits ?? this.credits,
      rawPrice: rawPrice ?? this.rawPrice,
      displayPrice: displayPrice ?? this.displayPrice,
    );
  }
}


