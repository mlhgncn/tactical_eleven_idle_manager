class PlayerPack {
  final String id;
  final String name;
  final int diamondCost;
  final int guaranteedMinAbility;
  final int randomMinAbility;
  final int randomMaxAbility;
  final int randomSlotCount;

  PlayerPack({
    required this.id,
    required this.name,
    required this.diamondCost,
    required this.guaranteedMinAbility,
    required this.randomMinAbility,
    required this.randomMaxAbility,
    required this.randomSlotCount,
  });

  factory PlayerPack.fromMap(Map<String, dynamic> map) {
    return PlayerPack(
      id: map['id'] as String,
      name: map['name'] as String,
      diamondCost: (map['diamond_cost'] as num).toInt(),
      guaranteedMinAbility: (map['guaranteed_min_ability'] as num).toInt(),
      randomMinAbility: (map['random_min_ability'] as num).toInt(),
      randomMaxAbility: (map['random_max_ability'] as num).toInt(),
      randomSlotCount: (map['random_slot_count'] as num).toInt(),
    );
  }
}
