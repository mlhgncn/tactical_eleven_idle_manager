class TransferMarketItem {
  final String id;
  final String playerId;
  final int currentHighestBid;
  final String? highestBidderId;
  final DateTime endTime;

  TransferMarketItem({
    required this.id,
    required this.playerId,
    required this.currentHighestBid,
    this.highestBidderId,
    required this.endTime,
  });

  bool get isSold => DateTime.now().isAfter(endTime);

  factory TransferMarketItem.fromMap(Map<String, dynamic> map) {
    return TransferMarketItem(
      id: map['id'] as String,
      playerId: map['player_id'] as String,
      currentHighestBid: (map['current_highest_bid'] as num).toInt(),
      highestBidderId: map['highest_bidder_id'] as String?,
      endTime: DateTime.parse(map['end_time'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'player_id': playerId,
      'current_highest_bid': currentHighestBid,
      'highest_bidder_id': highestBidderId,
      'end_time': endTime.toIso8601String(),
    };
  }
}
