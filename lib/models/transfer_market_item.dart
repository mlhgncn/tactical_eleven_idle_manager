class TransferMarketItem {
  final String id;
  final String playerId;
  final String playerName;
  final String playerPosition;
  final int currentAbility;
  final int age;
  final int askingPrice;
  final String? sellerClubId;
  final String? sellerClubName;
  final int potentialAbility;
  final int morale;
  final int fitness;
  final int finishing;
  final int passing;
  final int tackling;
  final int composure;
  final int determination;
  final int consistency;
  final int injuryProneness;
  final double formRating;
  final String? injuryType;
  final int injuryDurationWeeks;
  final bool isSuspended;

  TransferMarketItem({
    required this.id,
    required this.playerId,
    required this.playerName,
    required this.playerPosition,
    required this.currentAbility,
    required this.age,
    required this.askingPrice,
    this.sellerClubId,
    this.sellerClubName,
    this.potentialAbility = 0,
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
  });

  String get sellerClubDisplayName => sellerClubName ?? 'Bilinmiyor';

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

  double get starRating => (currentAbility / 20).clamp(0, 5).toDouble();

  factory TransferMarketItem.fromMap(Map<String, dynamic> map) {
    final playerData = map['players'] as Map<String, dynamic>?;
    final sellerClubData = playerData != null ? playerData['club'] as Map<String, dynamic>? : null;

    return TransferMarketItem(
      id: map['id'] as String,
      playerId: map['player_id'] as String,
      playerName: playerData != null ? playerData['name'] as String : (map['player_name'] as String? ?? 'Bilinmiyor'),
      playerPosition: playerData != null ? playerData['position'] as String : (map['player_position'] as String? ?? '-'),
      currentAbility: playerData != null ? (playerData['current_ability'] as num?)?.toInt() ?? 0 : 0,
      age: playerData != null ? (playerData['age'] as num?)?.toInt() ?? 0 : 0,
      askingPrice: (map['asking_price'] as num).toInt(),
      sellerClubId: sellerClubData?['id'] as String?,
      sellerClubName: sellerClubData?['name'] as String?,
      potentialAbility: playerData != null ? (playerData['potential_ability'] as num?)?.toInt() ?? 0 : 0,
      morale: playerData != null ? (playerData['morale'] as num?)?.toInt() ?? 75 : 75,
      fitness: playerData != null ? (playerData['fitness'] as num?)?.toInt() ?? 100 : 100,
      finishing: playerData != null ? (playerData['finishing'] as num?)?.toInt() ?? 10 : 10,
      passing: playerData != null ? (playerData['passing'] as num?)?.toInt() ?? 10 : 10,
      tackling: playerData != null ? (playerData['tackling'] as num?)?.toInt() ?? 10 : 10,
      composure: playerData != null ? (playerData['composure'] as num?)?.toInt() ?? 10 : 10,
      determination: playerData != null ? (playerData['determination'] as num?)?.toInt() ?? 10 : 10,
      consistency: playerData != null ? (playerData['consistency'] as num?)?.toInt() ?? 10 : 10,
      injuryProneness: playerData != null ? (playerData['injury_proneness'] as num?)?.toInt() ?? 5 : 5,
      formRating: playerData != null ? (playerData['form_rating'] as num?)?.toDouble() ?? 0.0 : 0.0,
      injuryType: playerData != null ? playerData['injury_type'] as String? : null,
      injuryDurationWeeks: playerData != null ? (playerData['injury_duration_weeks'] as num?)?.toInt() ?? 0 : 0,
      isSuspended: playerData != null ? (playerData['is_suspended'] as bool?) ?? false : false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'player_id': playerId,
      'player_name': playerName,
      'player_position': playerPosition,
      'current_ability': currentAbility,
      'age': age,
      'asking_price': askingPrice,
      'seller_club_id': sellerClubId,
      'seller_club_name': sellerClubName,
      'potential_ability': potentialAbility,
      'morale': morale,
      'fitness': fitness,
      'finishing': finishing,
      'passing': passing,
      'tackling': tackling,
      'composure': composure,
      'determination': determination,
      'consistency': consistency,
      'injury_proneness': injuryProneness,
      'form_rating': formRating,
      'injury_type': injuryType,
      'injury_duration_weeks': injuryDurationWeeks,
      'is_suspended': isSuspended,
    };
  }
}
