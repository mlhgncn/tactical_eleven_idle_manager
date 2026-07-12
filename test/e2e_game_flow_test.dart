import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tactical_eleven_idle_manager/models/bank.dart';
import 'package:tactical_eleven_idle_manager/models/club_info.dart';
import 'package:tactical_eleven_idle_manager/models/inbox_message.dart';
import 'package:tactical_eleven_idle_manager/models/league_club_option.dart';
import 'package:tactical_eleven_idle_manager/models/opponent_scout_report.dart';
import 'package:tactical_eleven_idle_manager/models/player_fm.dart';
import 'package:tactical_eleven_idle_manager/models/profile.dart';
import 'package:tactical_eleven_idle_manager/models/transfer_market_item.dart';
import 'package:tactical_eleven_idle_manager/models/transfer_offer.dart';
import 'package:tactical_eleven_idle_manager/models/transfer_history_entry.dart';
import 'package:tactical_eleven_idle_manager/models/tactics.dart';
import 'package:tactical_eleven_idle_manager/models/match_result.dart';
import 'package:tactical_eleven_idle_manager/models/financial_transaction.dart';
import 'package:tactical_eleven_idle_manager/models/player_pack.dart';
import 'package:tactical_eleven_idle_manager/models/diamond_product.dart';
import 'package:tactical_eleven_idle_manager/providers/game_provider.dart';
import 'package:tactical_eleven_idle_manager/repositories/repository_interface.dart';
import 'package:tactical_eleven_idle_manager/screens/auth_screen.dart';
import 'package:tactical_eleven_idle_manager/screens/email_verification_screen.dart';
import 'package:tactical_eleven_idle_manager/screens/root_shell.dart';
import 'package:tactical_eleven_idle_manager/screens/setup_club_screen.dart';
import 'package:tactical_eleven_idle_manager/services/auth_repository.dart';
import 'package:tactical_eleven_idle_manager/widgets/themed_button.dart';

class _FakeAuthRepository implements AuthRepository {
  // Starts signed-out like a real fresh Supabase session, so AuthScreen's
  // resume-existing-session check doesn't skip straight past the login form
  // in tests.
  String? _currentUserId;

  @override
  String? get currentUserId => _currentUserId;

  @override
  Future<dynamic> signIn(String email, String password) async {
    _currentUserId = 'test-user-1';
    return _FakeAuthResponse(
      user: _FakeUser(id: currentUserId!),
      session: _FakeSession(user: _FakeUser(id: currentUserId!)),
    );
  }

  @override
  Future<dynamic> signUp(String email, String password, {String? username}) async {
    _currentUserId = 'test-user-1';
    return _FakeAuthResponse(
      user: _FakeUser(id: currentUserId!),
      session: _FakeSession(user: _FakeUser(id: currentUserId!)),
    );
  }

  @override
  Future<void> signOut() async {
    _currentUserId = null;
  }

  @override
  Future<void> updateEmail(String newEmail) async {}

  @override
  Future<void> updatePassword(String newPassword) async {}

  @override
  String? get currentUserEmail => 'test@example.com';
}

class _FakeAuthResponse {
  final _FakeUser user;
  final _FakeSession? session;

  _FakeAuthResponse({required this.user, required this.session});
}

class _FakeUser {
  final String id;
  final DateTime? emailConfirmedAt = DateTime.now();

  _FakeUser({required this.id});
}

class _FakeSession {
  final _FakeUser user;
  final DateTime? emailConfirmedAt = DateTime.now();

  _FakeSession({required this.user});
}

class _FakeGameRepository implements GameRepository {
  String? _currentUserId = 'test-user-1';
  ClubInfo? _activeClub;
  final List<InboxMessage> _inboxMessages = [];

  @override
  String? get currentUserId => _currentUserId;

  @override
  Future<ClubInfo?> loadActiveClub({String? clubId}) async => _activeClub;

  @override
  Future<List<ClubInfo>> loadMyClubs() async => _activeClub == null ? [] : [_activeClub!];

  @override
  Future<Profile?> loadProfile() async {
    return Profile(
      id: currentUserId ?? 'unknown',
      fullName: 'Test Manager',
      avatarUrl: null,
      email: 'test@example.com',
      language: 'tr',
      fcmToken: null,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<Profile?> updateUsername(String username) async => loadProfile();

  @override
  Future<List<LeagueClubOption>> previewLeagueTheme(String theme) async {
    return [
      LeagueClubOption(clubId: 'club-created', clubName: 'Zero Account FC', quality: 50, isPremiumLocked: false),
    ];
  }

  @override
  Future<List<LeagueClubOption>> previewLeagueByCode(String invitationCode) async {
    return [
      LeagueClubOption(clubId: 'club-joined', clubName: 'Joined FC', quality: 50, isPremiumLocked: false),
    ];
  }

  @override
  Future<ClubInfo?> selectClubForLeague(String clubId) async {
    final club = ClubInfo(
      id: clubId,
      name: 'Zero Account FC',
      budget: 10000,
      stadiumCapacity: 5000,
      ticketPrice: 5,
      trainingFacilityLevel: 1,
      sponsorLevel: 1,
      lastMaintenanceDate: DateTime.now(),
    );
    _activeClub = club;
    return club;
  }

  @override
  Future<ClubInfo?> joinLeagueWithCode(String invitationCode) async {
    final club = ClubInfo(
      id: 'club-joined',
      name: 'Joined FC',
      budget: 10000,
      stadiumCapacity: 5000,
      ticketPrice: 5,
      trainingFacilityLevel: 1,
      sponsorLevel: 1,
      lastMaintenanceDate: DateTime.now(),
    );
    _activeClub = club;
    return club;
  }

  @override
  Future<void> leaveCurrentClub({String? clubId}) async {
    _activeClub = null;
  }

  @override
  Future<void> deleteAccount() async {
    _activeClub = null;
  }

  @override
  Future<List<PlayerFM>> loadSquadPlayers(String clubId) async {
    return List<PlayerFM>.generate(
      11,
      (index) => PlayerFM(
        id: 'player-$index',
        clubId: clubId,
        name: 'Test Player ${index + 1}',
        position: 'Position ${index + 1}',
        age: 19 + (index % 5),
        currentAbility: 50 + index,
        potentialAbility: 60 + index,
        morale: 80,
        fitness: 90,
        finishing: 70,
        passing: 65,
        tackling: 60,
        composure: 62,
        determination: 68,
        consistency: 70,
        injuryProneness: 10,
      ),
    );
  }

  @override
  Future<PlayerFM?> loadPlayerById(String playerId) async => null;

  @override
  Future<List<Bank>> loadBanks() async => [];

  @override
  Future<List<BankDeposit>> loadBankDeposits(String clubId) async => [];

  @override
  Future<BankDeposit?> depositToBank({required String bankId, required int amount}) async => null;

  @override
  Future<ClubInfo?> withdrawFromBank({required String depositId}) async => null;

  @override
  Future<List<InboxMessage>> loadInboxMessages() async => List<InboxMessage>.from(_inboxMessages);

  @override
  Future<InboxMessage?> addInboxMessage({required String title, required String body}) async => null;

  @override
  Future<List<Map<String, dynamic>>> loadFixturesForClub(String clubId) async => [
        {
          'id': 'fixture-1',
          'home_club_id': clubId,
          'away_club_id': 'opponent-club-1',
          'away_club': {'name': 'Rakip FC'},
          'match_date': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
          'is_played': false,
          'home_score': 0,
          'away_score': 0,
          'week': 1,
        },
      ];

  @override
  Future<Map<String, dynamic>?> awardAdReward({required String rewardType, int? amount}) async => null;

  @override
  Future<List<TransferMarketItem>> loadTransferMarket() async => <TransferMarketItem>[];

  @override
  Future<Tactics?> loadTacticsForClub(String clubId) async => null;

  @override
  Future<Tactics?> loadTactics(String clubId) async => null;

  @override
  Future<Tactics?> saveTacticsForClub(String clubId, Tactics tactics) async => null;

  @override
  Future<Tactics?> saveTactics(String clubId, Tactics tactics) async => null;

  @override
  Future<TransferMarketItem?> listPlayerForTransfer({required String playerId, required int askingPrice}) async => null;

  @override
  Future<void> withdrawTransferListing({required String playerId}) async {}

  @override
  Future<List<TransferHistoryEntry>> loadTransferHistory(String clubId) async => <TransferHistoryEntry>[];

  @override
  Future<List<PlayerFM>> loadFreeAgents() async => <PlayerFM>[];

  @override
  Future<ClubInfo?> signFreeAgent({required String playerId}) async => null;

  @override
  Future<TransferOffer?> makeTransferOffer({required String playerId, required int offerAmount}) async => null;

  @override
  Future<void> respondToTransferOffer({required String offerId, required bool accept}) async {}

  @override
  Future<void> withdrawTransferOffer({required String offerId}) async {}

  @override
  Future<List<TransferOffer>> loadIncomingTransferOffers(String clubId) async => <TransferOffer>[];

  @override
  Future<List<TransferOffer>> loadOutgoingTransferOffers(String clubId) async => <TransferOffer>[];

  @override
  Future<List<PlayerPack>> loadPlayerPacks() async => <PlayerPack>[];

  @override
  Future<List<PlayerFM>> openPlayerPack({required String packId}) async => <PlayerFM>[];

  @override
  Future<List<DiamondProduct>> loadDiamondProducts() async => <DiamondProduct>[];

  @override
  Future<Map<String, dynamic>> verifyIapPurchase({
    required String receiptData,
    required String productId,
    required String transactionId,
  }) async =>
      <String, dynamic>{'success': true, 'diamondsCredited': 0};

  @override
  Future<bool> markMessageAsRead(String messageId) async => true;

  @override
  Future<ClubInfo?> startClubDevelopment({
    required String clubId,
    required String upgradeType,
    required int targetValue,
  }) async {
    if (_activeClub == null) return null;
    final updatedClub = switch (upgradeType) {
      'stadium' => _activeClub!.copyWith(stadiumCapacity: targetValue),
      'facility' => _activeClub!.copyWith(trainingFacilityLevel: targetValue),
      _ => _activeClub!.copyWith(ticketPriceLevel: targetValue),
    };
    _activeClub = updatedClub;
    return updatedClub;
  }

  @override
  Future<ClubInfo?> upgradeSponsor({required String clubId}) async {
    if (_activeClub == null) return null;
    final nextLevel = (_activeClub!.sponsorLevel + 1).clamp(1, 5);
    final updatedClub = _activeClub!.copyWith(sponsorLevel: nextLevel);
    _activeClub = updatedClub;
    return updatedClub;
  }

  @override
  Future<void> updateFcmToken(String token) async {}

  @override
  Future<void> updateNotificationPreference(bool enabled) async {}

  @override
  Future<bool?> loadNotificationPreference() async => null;

  @override
  Future<PlayerFM?> startPlayerDevelopment({required String playerId}) async => null;

  @override
  Future<PlayerFM?> reducePlayerDevelopmentTimeWithAd({required String playerId}) async => null;

  @override
  Future<ClubInfo?> reduceClubDevelopmentTimeWithAd({required String clubId}) async => null;

  @override
  Future<Map<String, dynamic>?> loadCurrentSeasonState(String clubId) async => null;

  @override
  Future<List<Map<String, dynamic>>> loadLeagueStandings(String seasonId) async => <Map<String, dynamic>>[];
  @override
  Future<List<Map<String, dynamic>>> loadMatchEvents(String matchId) async => <Map<String, dynamic>>[];
  @override
  Future<List<FinancialTransaction>> loadFinancialTransactions(String clubId) async => <FinancialTransaction>[];

  @override
  Future<MatchResult?> playNextFixture() async {
    final activeClub = _activeClub;
    if (activeClub == null) return null;

    const homeScore = 2;
    const awayScore = 1;
    const ticketRevenue = 500;

    _activeClub = activeClub.copyWith(budget: activeClub.budget + ticketRevenue);

    _inboxMessages.insert(
      0,
      InboxMessage(
        id: 'inbox-${_inboxMessages.length + 1}',
        title: 'Maç Sonucu',
        body: '${activeClub.name} $homeScore - $awayScore Rakip FC',
        isRead: false,
        createdAt: DateTime.now(),
      ),
    );

    return MatchResult(
      homeTeamId: activeClub.id,
      awayTeamId: 'opponent-club-1',
      homeScore: homeScore,
      awayScore: awayScore,
      homeShots: 10,
      awayShots: 6,
      homeXg: 1.8,
      awayXg: 0.9,
      homePossession: 55,
      summary: 'Ev sahibi takım maçı kazandı.',
      commentary: const ['Maç başladı.', 'Gol!', 'Maç sona erdi.'],
      events: const [],
    );
  }

  @override
  Future<OpponentScoutReport> scoutOpponent(String matchId) async {
    return OpponentScoutReport(clubId: 'opponent-club-1', players: const [], tactics: null);
  }

  // Admin RPC stubs to satisfy GameRepository interface for widget tests
  @override
  Future<bool> isAdmin() async => true;

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
  Future<Map<String, dynamic>?> adminUpdatePlayer({required String playerId, String? name, String? position, int? currentAbility, int? potentialAbility, int? age}) async => null;
}

void main() {
  testWidgets('Full game flow from zero account to match play', (WidgetTester tester) async {
    print('TEST: start');
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();

    // Skip Supabase initialization in widget tests to avoid network and plugin issues.
    print('TEST: skipping Supabase.initialize in widget test');

    final fakeAuth = _FakeAuthRepository();
    final fakeRepo = _FakeGameRepository();
    
    bool notificationSent = false;
    Future<void> testNotificationSender(String title, String body) async {
      notificationSent = true;
      expect(title, contains('Maç Sonucu'));
      expect(body, contains('Zero Account FC'));
    }

    final gameProvider = GameProvider(
      repository: fakeRepo,
      notificationSender: testNotificationSender,
      enableRealtime: false,
    );

    print('TEST: pumpWidget start');
    await tester.pumpWidget(
      EasyLocalization(
        startLocale: const Locale('tr'),
        supportedLocales: const [Locale('tr')],
        path: 'assets/translations',
        fallbackLocale: const Locale('tr'),
        child: ChangeNotifierProvider<GameProvider>.value(
          value: gameProvider,
          // Builder gives us a BuildContext that's a descendant of
          // EasyLocalization, so context.localizationDelegates/supportedLocales
          // below actually resolve to easy_localization's loaded delegate
          // instead of silently falling back to Flutter's defaults (which is
          // what left every `.tr()` call unresolved before this fix).
          child: Builder(
            builder: (context) => MaterialApp(
              initialRoute: '/auth',
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              routes: {
                '/auth': (_) => AuthScreen(authRepository: fakeAuth),
                '/email-verification': (_) => const EmailVerificationScreen(),
                '/setup-club': (_) => SetupClubScreen(),
                '/root': (_) => RootShell(),
              },
            ),
          ),
        ),
      ),
    );
    print('TEST: pumpWidget completed');

    await tester.pumpAndSettle(const Duration(seconds: 2));
    print('TEST: pumpAndSettle completed');
    expect(find.text('Giriş Yap'), findsWidgets);

    await tester.tap(find.text('Henüz hesabın yok mu? Kayıt ol'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Kayıt Ol'), findsWidgets);

    final textFields = find.byType(TextFormField);
    expect(textFields, findsWidgets);

    await tester.enterText(textFields.at(0), 'testuser');
    await tester.enterText(textFields.at(1), 'test@example.com');
    await tester.enterText(textFields.at(2), 'password123');
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    await tester.tap(find.widgetWithText(GoldButton, 'Kayıt Ol'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    
    expect(find.text('Menajerliğe Başla'), findsOneWidget);

    await tester.tap(find.widgetWithText(GoldButton, 'Lig Oluştur'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Zero Account FC'), findsOneWidget);
    await tester.tap(find.text('Zero Account FC'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    await tester.tap(find.text('Onayla'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(gameProvider.activeClub, isNotNull);
    expect(gameProvider.activeClub!.name, 'Zero Account FC');

    // Dashboard ("Kulüp") is now the landing tab - Finans moved to its own tab.
    await tester.tap(find.text('Finans'));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(find.text('Kulüp Finansları'), findsOneWidget);

    await tester.tap(find.text('Kadro'));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(find.textContaining('İlk 11'), findsOneWidget);

    await tester.tap(find.text('Taktik'));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(find.text('OYUN ANLAYIŞI'), findsOneWidget);
    await tester.drag(find.text('OYUN ANLAYIŞI'), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(GoldButton, 'TAKTİĞİ KAYDET'));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    final initialBudget = gameProvider.activeClub!.budget;
    await gameProvider.playNextFixture();
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(gameProvider.results, isNotEmpty);
    expect(gameProvider.inboxMessages.first.title, 'Maç Sonucu');
    expect(gameProvider.activeClub!.budget, greaterThan(initialBudget));
    expect(notificationSent, isTrue);
  });
}
