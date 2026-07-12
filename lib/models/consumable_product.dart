class ConsumableProduct {
  final String id;
  final String name;
  final int diamondCost;
  final String effectType; // 'tactic_hide' | 'camp'
  final int grantQuantity;

  ConsumableProduct({
    required this.id,
    required this.name,
    required this.diamondCost,
    required this.effectType,
    required this.grantQuantity,
  });

  factory ConsumableProduct.fromMap(Map<String, dynamic> map) {
    return ConsumableProduct(
      id: map['id'] as String,
      name: map['name'] as String,
      diamondCost: (map['diamond_cost'] as num).toInt(),
      effectType: map['effect_type'] as String,
      grantQuantity: (map['grant_quantity'] as num).toInt(),
    );
  }
}
