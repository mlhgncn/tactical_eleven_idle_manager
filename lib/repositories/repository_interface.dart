import '../models/club_info.dart';
import '../models/inbox_message.dart';
import '../models/match_result.dart';
import '../models/player_fm.dart';
import '../models/profile.dart';
import '../models/transfer_market_item.dart';
import '../models/tactics.dart';
import '../models/offline_simulation_result.dart';
import '../models/financial_transaction.dart';

abstract class GameRepository {
  String? get currentUserId;
  Future<ClubInfo?> loadActiveClub();
  Future<Profile?> loadProfile();
  Future<List<ClubInfo>> loadAvailableClubs();
  Future<ClubInfo?> createClub(String name);
  Future<ClubInfo?> claimClub(String clubId);
  Future<List<PlayerFM>> loadSquadPlayers(String clubId);
  Future<PlayerFM?> advancePlayerDevelopment({
    required String playerId,
    required int minutesPlayed,
    required int trainingFacilityLevel,
    required int morale,
    required double formRating,
  });
  // Assign players to clubs based on seed `team_id` when `club_id` is null
  Future<void> assignPlayersFromTeamIds();
  Future<List<InboxMessage>> loadInboxMessages();
  Future<InboxMessage?> addInboxMessage({required String title, required String body});
  Future<Map<String, dynamic>?> awardAdReward({required String rewardType, int? amount});
  Future<List<TransferMarketItem>> loadTransferMarket();
  Future<List<Map<String, dynamic>>> loadFixturesForClub(String clubId);
  Future<Map<String, dynamic>?> loadCurrentSeasonState(String clubId);
  Future<List<Map<String, dynamic>>> loadLeagueStandings(String seasonId);
  Future<List<FinancialTransaction>> loadFinancialTransactions(String clubId);
  Future<Tactics?> loadTacticsForClub(String clubId);
  Future<Tactics?> loadTactics(String clubId);
  Future<Tactics?> saveTacticsForClub(String clubId, Tactics tactics);
  Future<Tactics?> saveTactics(String clubId, Tactics tactics);
  Future<TransferMarketItem?> placeBid(String marketId, int bidAmount);
  Future<TransferMarketItem?> listPlayerForTransfer({required String playerId, required int askingPrice});
  Future<void> withdrawTransferListing({required String playerId});
  Future<ClubInfo?> acceptTransferOffer({required String playerId});
  Future<bool> markMessageAsRead(String messageId);
  Future<ClubInfo?> upgradeClub({
    required String clubId,
    int? stadiumCapacity,
    int? trainingFacilityLevel,
    int? ticketPrice,
  });
  Future<ClubInfo?> upgradeSponsor({required String clubId});
  Future<void> updateFcmToken(String token);
  Future<void> updateNotificationPreference(bool enabled);
  Future<bool?> loadNotificationPreference();
  Future<void> touchLastActivity();
  Future<OfflineSimulationResult> simulateOfflineProgress();
  Future<MatchResult?> playNextFixture();
  // Admin actions
  Future<bool> isAdmin();
  Future<List<Map<String, dynamic>>> adminListUsers();
  Future<List<Map<String, dynamic>>> adminListClubs();
  Future<Map<String, dynamic>?> adminCreateGiftCode({required String code, required int amount, DateTime? expiresAt});
  Future<Map<String, dynamic>?> adminCreateEvent({required String title, required String body, DateTime? startsAt, DateTime? endsAt});
  Future<Map<String, dynamic>?> adminSendPush({required String title, required String body, String? targetUserId});
  Future<Map<String, dynamic>?> adminUpdatePlayer({required String playerId, String? name, String? position, int? age, int? currentAbility, int? potentialAbility});
}
