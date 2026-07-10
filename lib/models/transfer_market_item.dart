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
  });

  String get sellerClubDisplayName => sellerClubName ?? 'Bilinmiyor';

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
    };
  }
}
