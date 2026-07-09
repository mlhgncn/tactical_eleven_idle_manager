class TransferHistoryEntry {
  final String id;
  final String playerId;
  final String playerName;
  final String? sellerClubId;
  final String sellerClubName;
  final String? buyerClubId;
  final String buyerClubName;
  final int price;
  final DateTime completedAt;

  TransferHistoryEntry({
    required this.id,
    required this.playerId,
    required this.playerName,
    required this.sellerClubId,
    required this.sellerClubName,
    required this.buyerClubId,
    required this.buyerClubName,
    required this.price,
    required this.completedAt,
  });
}
