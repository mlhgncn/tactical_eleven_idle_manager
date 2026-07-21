class TransferOffer {
  final String id;
  final String playerId;
  final String playerName;
  final String fromClubId;
  final String fromClubName;
  final String toClubId;
  final String toClubName;
  final int offerAmount;
  final String status;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? parentOfferId;
  final int roundNumber;
  final String initiatedBy; // 'buyer' | 'seller' - who proposed offerAmount

  TransferOffer({
    required this.id,
    required this.playerId,
    required this.playerName,
    required this.fromClubId,
    required this.fromClubName,
    required this.toClubId,
    required this.toClubName,
    required this.offerAmount,
    required this.status,
    required this.createdAt,
    this.respondedAt,
    this.parentOfferId,
    this.roundNumber = 1,
    this.initiatedBy = 'buyer',
  });

  bool get isPending => status == 'pending';
  bool get isCountered => status == 'countered';
  bool get isNegotiated => roundNumber > 1;
  bool get canCounter => isPending && roundNumber < 5;

  factory TransferOffer.fromMap(Map<String, dynamic> map) {
    final playerData = map['player'] as Map<String, dynamic>?;
    final fromClubData = map['from_club'] as Map<String, dynamic>?;
    final toClubData = map['to_club'] as Map<String, dynamic>?;

    return TransferOffer(
      id: map['id'] as String,
      playerId: map['player_id'] as String,
      playerName: playerData?['name'] as String? ?? 'Bilinmiyor',
      fromClubId: map['from_club_id'] as String,
      fromClubName: fromClubData?['name'] as String? ?? 'Bilinmiyor',
      toClubId: map['to_club_id'] as String,
      toClubName: toClubData?['name'] as String? ?? 'Bilinmiyor',
      offerAmount: (map['offer_amount'] as num).toInt(),
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      respondedAt: map['responded_at'] != null ? DateTime.tryParse(map['responded_at'] as String) : null,
      parentOfferId: map['parent_offer_id'] as String?,
      roundNumber: (map['round_number'] as num?)?.toInt() ?? 1,
      initiatedBy: map['initiated_by'] as String? ?? 'buyer',
    );
  }
}
