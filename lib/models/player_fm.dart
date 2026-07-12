class PlayerFM {
  final String id;
  final String? clubId;
  final String name;
  final String position;
  int age;
  int currentAbility;
  int potentialAbility;
  int morale;
  int fitness;
  int finishing;
  int passing;
  int tackling;
  int composure;
  int determination;
  int consistency;
  int injuryProneness;
  double formRating;
  String? injuryType;
  int injuryDurationWeeks;
  bool isSuspended;
  DateTime? developmentCompletesAt;
  int developmentAdUses;
  String preferredFoot;

  PlayerFM({
    required this.id,
    required this.clubId,
    required this.name,
    required this.position,
    required this.age,
    required this.currentAbility,
    required this.potentialAbility,
    this.morale = 75,
    this.fitness = 100,
    this.finishing = 10,
    this.passing = 10,
    this.tackling = 10,
    this.composure = 10,
    this.determination = 10,
    this.consistency = 10,
    this.injuryProneness = 5,
    this.formRating = 0.0,
    this.injuryType,
    this.injuryDurationWeeks = 0,
    this.isSuspended = false,
    this.developmentCompletesAt,
    this.developmentAdUses = 0,
    this.preferredFoot = 'right',
  });

  factory PlayerFM.fromMap(Map<String, dynamic> map) {
    return PlayerFM(
      id: map['id'] as String,
      clubId: map['club_id'] as String?,
      name: map['name'] as String,
      position: map['position'] as String,
      age: (map['age'] as num).toInt(),
      currentAbility: (map['current_ability'] as num).toInt(),
      potentialAbility: (map['potential_ability'] as num).toInt(),
      morale: (map['morale'] as num).toInt(),
      fitness: (map['fitness'] as num).toInt(),
      finishing: (map['finishing'] as num).toInt(),
      passing: (map['passing'] as num).toInt(),
      tackling: (map['tackling'] as num).toInt(),
      composure: (map['composure'] as num).toInt(),
      determination: (map['determination'] as num).toInt(),
      consistency: (map['consistency'] as num).toInt(),
      injuryProneness: (map['injury_proneness'] as num).toInt(),
      formRating: (map['form_rating'] as num?)?.toDouble() ?? 0.0,
      injuryType: map['injury_type'] as String?,
      injuryDurationWeeks: (map['injury_duration_weeks'] as num?)?.toInt() ?? 0,
      isSuspended: (map['is_suspended'] as bool?) ?? false,
      developmentCompletesAt: map['development_completes_at'] != null
          ? DateTime.tryParse(map['development_completes_at'] as String)
          : null,
      developmentAdUses: (map['development_ad_uses'] as num?)?.toInt() ?? 0,
      preferredFoot: map['preferred_foot'] as String? ?? 'right',
    );
  }

  bool get isDeveloping =>
      developmentCompletesAt != null && developmentCompletesAt!.isAfter(DateTime.now());

  bool get hasActiveInjury {
    return injuryDurationWeeks > 0 || isSuspended || (injuryType?.trim().isNotEmpty ?? false);
  }

  String get injuryDisplayLabel {
    final parts = <String>[];
    if (injuryType != null && injuryType!.trim().isNotEmpty) {
      parts.add(injuryType!.trim());
    }
    if (injuryDurationWeeks > 0) {
      parts.add('$injuryDurationWeeks hafta');
    }
    if (isSuspended) {
      parts.add('cezalı');
    }
    return parts.isEmpty ? 'Sakatlık yok' : parts.join(' • ');
  }

  int get salary {
    return currentAbility * 250 + (potentialAbility - currentAbility) * 100 + age * 10;
  }

  // Rescaled /40 to match the club-budget economy - see
  // supabase/migrations/20260710145357_rebalance_club_economy_lower_budgets.sql
  // and sign_free_agent's mirrored formula, kept in sync with this one.
  int get marketValue {
    return (currentAbility * 15000 + potentialAbility * 5000 + age * 100) ~/ 40;
  }

  double get starRating {
    return (currentAbility / 20).clamp(0, 5).toDouble();
  }

  /// Serbest oyuncu imzalama maliyeti: satıcı kulübe ödenecek bir bedel
  /// olmadığından piyasa değerinin bir kısmı (sign_free_agent RPC'siyle
  /// aynı formül).
  int get signingCost => (marketValue * 0.4).round();

  String get salaryLabel => '$salary GP';

  String get marketValueLabel => '${(marketValue / 1000).round()}K GP';

  String get positionGroup {
    final upper = position.toUpperCase();
    if (upper == 'GK') return 'GK';
    const defPositions = ['CB', 'LB', 'RB', 'WB', 'LWB', 'RWB', 'FB'];
    if (defPositions.any(upper.startsWith)) return 'DEF';
    const midPositions = ['CM', 'CDM', 'CAM', 'LM', 'RM', 'DM', 'AM'];
    if (midPositions.any(upper.startsWith)) return 'MID';
    const fwPositions = ['ST', 'CF', 'LW', 'RW', 'LF', 'RF'];
    if (fwPositions.any(upper.startsWith)) return 'FOR';
    return 'All';
  }

  /// Short badge text for preferred foot: S(ol)/S(ağ)/Ç(ift) - used on
  /// compact player cards where a full label doesn't fit.
  String get preferredFootShortLabel => switch (preferredFoot) {
        'left' => 'S',
        'both' => 'Ç',
        _ => 'D',
      };
}
