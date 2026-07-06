class TransferMarketItem {
  final String id;
  final String playerId;
  final String playerName;
  final String playerPosition;
  final int currentHighestBid;
  final String? highestBidderId;
  final String? highestBidderName;
  final String? sellerClubId;
  final String? sellerClubName;
  final DateTime endTime;

  TransferMarketItem({
    required this.id,
    required this.playerId,
    required this.playerName,
    required this.playerPosition,
    required this.currentHighestBid,
    this.highestBidderId,
    this.highestBidderName,
    this.sellerClubId,
    this.sellerClubName,
    required this.endTime,
  });

  bool get isSold => DateTime.now().isAfter(endTime);

  String get highestBidderDisplayName => highestBidderName ?? 'Bekliyor';

  String get sellerClubDisplayName => sellerClubName ?? 'Bilinmiyor';

  factory TransferMarketItem.fromMap(Map<String, dynamic> map) {
    final playerData = map['players'] as Map<String, dynamic>?;
    final sellerClubData = playerData != null ? playerData['club'] as Map<String, dynamic>? : null;
    final highestBidderData = map['highest_bidder'] as Map<String, dynamic>?;

    return TransferMarketItem(
      id: map['id'] as String,
      playerId: map['player_id'] as String,
      playerName: playerData != null ? playerData['name'] as String : (map['player_name'] as String? ?? 'Bilinmiyor'),
      playerPosition: playerData != null ? playerData['position'] as String : (map['player_position'] as String? ?? '-'),
      currentHighestBid: (map['current_highest_bid'] as num).toInt(),
      highestBidderId: highestBidderData != null ? highestBidderData['id'] as String? : map['highest_bidder_id'] as String?,
      highestBidderName: highestBidderData != null ? highestBidderData['name'] as String? : null,
      sellerClubId: sellerClubData?['id'] as String?,
      sellerClubName: sellerClubData?['name'] as String?,
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
      'highest_bidder_name': highestBidderName,
      'seller_club_id': sellerClubId,
      'seller_club_name': sellerClubName,
      'end_time': endTime.toIso8601String(),
    };
  }
}
