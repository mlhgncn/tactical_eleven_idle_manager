import '../models/club_info.dart';
import '../models/inbox_message.dart';
import '../models/player_fm.dart';
import '../models/profile.dart';
import '../models/transfer_market_item.dart';

abstract class GameRepository {
  String? get currentUserId;
  Future<ClubInfo?> loadActiveClub();
  Future<Profile?> loadProfile();
  Future<List<ClubInfo>> loadAvailableClubs();
  Future<ClubInfo?> createClub(String name);
  Future<ClubInfo?> claimClub(String clubId);
  Future<List<PlayerFM>> loadSquadPlayers(String clubId);
  Future<List<InboxMessage>> loadInboxMessages();
  Future<List<TransferMarketItem>> loadTransferMarket();
  Future<TransferMarketItem?> placeBid(String marketId, int bidAmount);
  Future<ClubInfo?> acceptTransferOffer({required String clubId, required int newBudget, required String playerId});
  Future<bool> markMessageAsRead(String messageId);
  Future<ClubInfo?> upgradeClub({
    required String clubId,
    int? stadiumCapacity,
    int? trainingFacilityLevel,
    int? ticketPrice,
    required int budget,
  });
  Future<void> updateFcmToken(String token);
}
