import '../models/club_info.dart';
import '../models/inbox_message.dart';
import '../models/league_club_option.dart';
import '../models/match_result.dart';
import '../models/opponent_scout_report.dart';
import '../models/player_fm.dart';
import '../models/profile.dart';
import '../models/transfer_market_item.dart';
import '../models/transfer_offer.dart';
import '../models/transfer_history_entry.dart';
import '../models/tactics.dart';
import '../models/financial_transaction.dart';
import '../models/player_pack.dart';
import '../models/diamond_product.dart';

abstract class GameRepository {
  String? get currentUserId;
  Future<ClubInfo?> loadActiveClub({String? clubId});
  Future<List<ClubInfo>> loadMyClubs();
  Future<Profile?> loadProfile();
  Future<Profile?> updateUsername(String username);
  Future<List<LeagueClubOption>> previewLeagueTheme(String theme);
  Future<List<LeagueClubOption>> previewLeagueByCode(String invitationCode);
  Future<ClubInfo?> selectClubForLeague(String clubId);
  Future<ClubInfo?> joinLeagueWithCode(String invitationCode);
  Future<void> leaveCurrentClub({String? clubId});
  Future<void> deleteAccount();
  Future<List<PlayerFM>> loadSquadPlayers(String clubId);
  Future<PlayerFM?> loadPlayerById(String playerId);
  Future<PlayerFM?> startPlayerDevelopment({required String playerId});
  Future<PlayerFM?> reducePlayerDevelopmentTimeWithAd({required String playerId});
  Future<ClubInfo?> reduceClubDevelopmentTimeWithAd({required String clubId});
  Future<List<InboxMessage>> loadInboxMessages();
  Future<InboxMessage?> addInboxMessage({required String title, required String body});
  Future<Map<String, dynamic>?> awardAdReward({required String rewardType, int? amount});
  Future<List<TransferMarketItem>> loadTransferMarket();
  Future<List<Map<String, dynamic>>> loadFixturesForClub(String clubId);
  Future<List<Map<String, dynamic>>> loadMatchEvents(String matchId);
  Future<Map<String, dynamic>?> loadCurrentSeasonState(String clubId);
  Future<List<Map<String, dynamic>>> loadLeagueStandings(String seasonId);
  Future<List<FinancialTransaction>> loadFinancialTransactions(String clubId);
  Future<Tactics?> loadTacticsForClub(String clubId);
  Future<Tactics?> loadTactics(String clubId);
  Future<Tactics?> saveTacticsForClub(String clubId, Tactics tactics);
  Future<Tactics?> saveTactics(String clubId, Tactics tactics);
  Future<TransferMarketItem?> listPlayerForTransfer({required String playerId, required int askingPrice});
  Future<void> withdrawTransferListing({required String playerId});
  Future<List<TransferHistoryEntry>> loadTransferHistory(String clubId);
  Future<List<PlayerFM>> loadFreeAgents();
  Future<ClubInfo?> signFreeAgent({required String playerId});
  Future<TransferOffer?> makeTransferOffer({required String playerId, required int offerAmount});
  Future<void> respondToTransferOffer({required String offerId, required bool accept});
  Future<void> withdrawTransferOffer({required String offerId});
  Future<List<TransferOffer>> loadIncomingTransferOffers(String clubId);
  Future<List<TransferOffer>> loadOutgoingTransferOffers(String clubId);
  Future<List<PlayerPack>> loadPlayerPacks();
  Future<List<PlayerFM>> openPlayerPack({required String packId});
  Future<List<DiamondProduct>> loadDiamondProducts();
  Future<Map<String, dynamic>> verifyIapPurchase({
    required String receiptData,
    required String productId,
    required String transactionId,
  });
  Future<bool> markMessageAsRead(String messageId);
  Future<ClubInfo?> startClubDevelopment({
    required String clubId,
    required String upgradeType,
    required int targetValue,
  });
  Future<ClubInfo?> upgradeSponsor({required String clubId});
  Future<void> updateFcmToken(String token);
  Future<void> updateNotificationPreference(bool enabled);
  Future<bool?> loadNotificationPreference();
  Future<MatchResult?> playNextFixture();
  Future<OpponentScoutReport> scoutOpponent(String matchId);
  // Admin actions
  Future<bool> isAdmin();
  Future<List<Map<String, dynamic>>> adminListUsers();
  Future<List<Map<String, dynamic>>> adminListClubs();
  Future<Map<String, dynamic>?> adminCreateGiftCode({required String code, required int amount, DateTime? expiresAt});
  Future<Map<String, dynamic>?> adminCreateEvent({required String title, required String body, DateTime? startsAt, DateTime? endsAt});
  Future<Map<String, dynamic>?> adminSendPush({required String title, required String body, String? targetUserId});
  Future<Map<String, dynamic>?> adminUpdatePlayer({required String playerId, String? name, String? position, int? age, int? currentAbility, int? potentialAbility});
}
