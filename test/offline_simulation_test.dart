import 'package:flutter_test/flutter_test.dart';
import 'package:tactical_eleven_idle_manager/models/club_info.dart';
import 'package:tactical_eleven_idle_manager/models/inbox_message.dart';
import 'package:tactical_eleven_idle_manager/models/match_result.dart';
import 'package:tactical_eleven_idle_manager/models/offline_simulation_result.dart';
import 'package:tactical_eleven_idle_manager/models/player_fm.dart';
import 'package:tactical_eleven_idle_manager/models/profile.dart';
import 'package:tactical_eleven_idle_manager/models/tactics.dart';
import 'package:tactical_eleven_idle_manager/models/transfer_market_item.dart';
import 'package:tactical_eleven_idle_manager/models/financial_transaction.dart';
import 'package:tactical_eleven_idle_manager/providers/game_provider.dart';
import 'package:tactical_eleven_idle_manager/repositories/repository_interface.dart';

class _FakeRepository implements GameRepository {
  _FakeRepository({required this.offlineResult});

  final OfflineSimulationResult offlineResult;
  bool lastActivityTouched = false;

  @override
  String? get currentUserId => 'user-1';

  @override
  Future<ClubInfo?> loadActiveClub() async {
    return const ClubInfo(
      id: 'club-1',
      name: 'Test Club',
      budget: 100000,
      stadiumCapacity: 20000,
      ticketPrice: 10,
      trainingFacilityLevel: 2,
    );
  }

  @override
  Future<Profile?> loadProfile() async {
    return Profile(
      id: 'user-1',
      fullName: 'Test User',
      email: 'test@example.com',
      language: 'tr',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<ClubInfo>> loadAvailableClubs() async => <ClubInfo>[];

  @override
  Future<ClubInfo?> createClub(String name) async => null;

  @override
  Future<ClubInfo?> claimClub(String clubId) async => null;

  @override
  Future<List<PlayerFM>> loadSquadPlayers(String clubId) async => <PlayerFM>[];

  @override
  Future<void> assignPlayersFromTeamIds() async {}

  @override
  Future<List<InboxMessage>> loadInboxMessages() async => <InboxMessage>[];

  @override
  Future<InboxMessage?> addInboxMessage({required String title, required String body}) async => null;

  @override
  Future<List<TransferMarketItem>> loadTransferMarket() async => <TransferMarketItem>[];

  @override
  Future<Map<String, dynamic>?> awardAdReward({required String rewardType, int? amount}) async => null;

  @override
  Future<List<Map<String, dynamic>>> loadFixturesForClub(String clubId) async => <Map<String, dynamic>>[];

  @override
  Future<Tactics?> loadTacticsForClub(String clubId) async => null;

  @override
  Future<Tactics?> loadTactics(String clubId) async => null;

  @override
  Future<Tactics?> saveTacticsForClub(String clubId, Tactics tactics) async => null;

  @override
  Future<Tactics?> saveTactics(String clubId, Tactics tactics) async => null;

  @override
  Future<TransferMarketItem?> placeBid(String marketId, int bidAmount) async => null;

  @override
  Future<ClubInfo?> acceptTransferOffer({required String playerId}) async => null;

  @override
  Future<bool> markMessageAsRead(String messageId) async => true;

  @override
  Future<ClubInfo?> upgradeClub({required String clubId, int? stadiumCapacity, int? trainingFacilityLevel, int? ticketPrice}) async => null;

  @override
  Future<ClubInfo?> upgradeSponsor({required String clubId}) async => null;

  @override
  Future<void> updateFcmToken(String token) async {}

  @override
  Future<void> updateNotificationPreference(bool enabled) async {}

  @override
  Future<bool?> loadNotificationPreference() async => null;

  @override
  Future<PlayerFM?> advancePlayerDevelopment({
    required String playerId,
    required int minutesPlayed,
    required int trainingFacilityLevel,
    required int morale,
    required double formRating,
  }) async => null;

  @override
  Future<void> touchLastActivity() async {
    lastActivityTouched = true;
  }

  @override
  Future<Map<String, dynamic>?> loadCurrentSeasonState(String clubId) async => null;

  @override
  Future<List<Map<String, dynamic>>> loadLeagueStandings(String seasonId) async => <Map<String, dynamic>>[];

  @override
  Future<MatchResult?> playNextFixture() async => null;

  @override
  Future<List<FinancialTransaction>> loadFinancialTransactions(String clubId) async => <FinancialTransaction>[];

  @override
  Future<bool> isAdmin() async => false;

  @override
  Future<List<Map<String, dynamic>>> adminListUsers() async => <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> adminListClubs() async => <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>?> adminCreateGiftCode({required String code, required int amount, DateTime? expiresAt}) async => null;

  @override
  Future<Map<String, dynamic>?> adminCreateEvent({required String title, required String body, DateTime? startsAt, DateTime? endsAt}) async => null;

  @override
  Future<Map<String, dynamic>?> adminSendPush({required String title, required String body, String? targetUserId}) async => null;

  @override
  Future<Map<String, dynamic>?> adminUpdatePlayer({required String playerId, String? name, String? position, int? age, int? currentAbility, int? potentialAbility}) async => null;

  @override
  Future<OfflineSimulationResult> simulateOfflineProgress() async {
    return offlineResult;
  }
}

void main() {
  test('simulateOfflineMatches uses the server-side offline result', () async {
    final result = OfflineSimulationResult(
      matchesSimulated: 2,
      totalIncome: 24000,
      playersImproved: 1,
      transferOffersReceived: 1,
      inboxMessagesAdded: 2,
      offlineDuration: const Duration(hours: 48),
    );

    final repository = _FakeRepository(offlineResult: result);
    final provider = GameProvider(
      repository: repository,
      enableRealtime: false,
      isSupabaseReady: false,
    );

    await provider.refreshGameState();
    final simulated = await provider.simulateOfflineMatches();

    expect(simulated.matchesSimulated, 2);
    expect(simulated.totalIncome, 24000);
    expect(repository.lastActivityTouched, isTrue);
  });
}
