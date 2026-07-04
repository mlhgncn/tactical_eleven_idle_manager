class TransferMarketItem {
  final String id;
  final String playerId;
  final String playerName;
  final String playerPosition;
  final int currentHighestBid;
  final String? highestBidderId;
  final DateTime endTime;

  TransferMarketItem({
    required this.id,
    required this.playerId,
    required this.playerName,
    required this.playerPosition,
    required this.currentHighestBid,
    this.highestBidderId,
    required this.endTime,
  });

  bool get isSold => DateTime.now().isAfter(endTime);

  factory TransferMarketItem.fromMap(Map<String, dynamic> map) {
    final playerData = map['players'] as Map<String, dynamic>?;

    return TransferMarketItem(
      id: map['id'] as String,
      playerId: map['player_id'] as String,
      playerName: playerData != null ? playerData['name'] as String : (map['player_name'] as String? ?? 'Bilinmiyor'),
      playerPosition: playerData != null ? playerData['position'] as String : (map['player_position'] as String? ?? '-'),
      currentHighestBid: (map['current_highest_bid'] as num).toInt(),
      highestBidderId: map['highest_bidder_id'] as String?,
      endTime: DateTime.parse(map['end_time'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'player_id': playerId,
      'player_name': playerName,
      'player_position': playerPosition,
      'current_highest_bid': currentHighestBid,
      'highest_bidder_id': highestBidderId,
      'end_time': endTime.toIso8601String(),
    };
  }
}
