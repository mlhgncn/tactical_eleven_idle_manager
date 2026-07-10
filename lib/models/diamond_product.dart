class DiamondProduct {
  final String productId;
  final int diamonds;
  final String label;
  final String? bonusNote;

  DiamondProduct({
    required this.productId,
    required this.diamonds,
    required this.label,
    this.bonusNote,
  });

  factory DiamondProduct.fromMap(Map<String, dynamic> map) {
    return DiamondProduct(
      productId: map['product_id'] as String,
      diamonds: (map['diamonds'] as num).toInt(),
      label: map['label'] as String,
      bonusNote: map['bonus_note'] as String?,
    );
  }
}
