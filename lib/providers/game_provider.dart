import 'package:flutter/material.dart';

import '../models/bank.dart';
import '../models/club_info.dart';
import '../models/inbox_message.dart';
import '../models/league_club_option.dart';
import '../models/opponent_scout_report.dart';
import '../models/match_fixture.dart';
import '../models/match_result.dart';
import '../models/player_fm.dart';
import '../models/financial_transaction.dart';
import '../models/profile.dart';
import '../models/tactics.dart';
import '../models/transfer_market_item.dart';
import '../models/transfer_offer.dart';
import '../models/transfer_history_entry.dart';
import '../models/player_pack.dart';
import '../models/diamond_product.dart';
import '../models/consumable_product.dart';
import '../repositories/match_preview_repository.dart';
import '../repositories/repository_interface.dart';
import '../repositories/supabase_repository.dart';
import '../services/notification_service.dart';
import '../services/analytics_service.dart';

class GameProvider extends ChangeNotifier {
  GameProvider({
    GameRepository? repository,
    MatchPreviewRepository? matchRepository,
    Future<void> Function(String title, String body)? notificationSender,
    bool enableRealtime = true,
    bool isSupabaseReady = true,
  })  : _repository = repository ?? SupabaseRepository(),
        _matchRepository = matchRepository ?? MatchPreviewRepository(),
        _notificationSender = notificationSender,
        _enableRealtime = enableRealtime,
        _isSupabaseReady = isSupabaseReady {
    if (_enableRealtime && _isSupabaseReady) {
      _initRealtimeStreams();
    }
  }

  final GameRepository _repository;
  final MatchPreviewRepository _matchRepository;
  final Future<void> Function(String title, String body)? _notificationSender;
  final bool _enableRealtime;
  final bool _isSupabaseReady;
  
  // Public getters for UI access
  ClubInfo? get activeClub => _activeClub;
  Profile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;
  bool get isSyncing => _isSyncing;
  List<PlayerFM> get squadPlayers => List.unmodifiable(_squadPlayers);
  List<MatchFixture> get fixtures => List.unmodifiable(_fixtures);
  List<MatchResult> get results => List.unmodifiable(_results);
  List<InboxMessage> get inboxMessages => List.unmodifiable(_inboxMessages);
  int get unreadInboxCount => _inboxMessages.where((m) => !m.isRead).length;
  List<TransferMarketItem> get transferMarketItems =>
      List.unmodifiable(_transferMarketItems);
  List<PlayerFM> get freeAgents => List.unmodifiable(_freeAgents);
  List<TransferOffer> get incomingTransferOffers => List.unmodifiable(_incomingTransferOffers);
  List<TransferOffer> get outgoingTransferOffers => List.unmodifiable(_outgoingTransferOffers);
  int get pendingIncomingOfferCount => _incomingTransferOffers.where((o) => o.isPending).length;
  List<PlayerPack> get playerPacks => List.unmodifiable(_playerPacks);
  List<DiamondProduct> get diamondProducts => List.unmodifiable(_diamondProducts);
  List<ConsumableProduct> get consumableProducts => List.unmodifiable(_consumableProducts);
  int get diamonds => _profile?.diamonds ?? 0;
  Tactics? get tactics => _tactics;

  bool get isSupabaseReady => _isSupabaseReady;

  bool _isAdmin = false;
  bool get isAdmin => _isAdmin;

  // Internal state
  ClubInfo? _activeClub;
  Profile? _profile;
  List<PlayerFM> _squadPlayers = <PlayerFM>[];
  List<MatchFixture> _fixtures = <MatchFixture>[];
  List<MatchResult> _results = <MatchResult>[];
  List<InboxMessage> _inboxMessages = <InboxMessage>[];
  List<TransferMarketItem> _transferMarketItems = <TransferMarketItem>[];
  List<PlayerFM> _freeAgents = <PlayerFM>[];
  List<TransferOffer> _incomingTransferOffers = <TransferOffer>[];
  List<TransferOffer> _outgoingTransferOffers = <TransferOffer>[];
  List<PlayerPack> _playerPacks = <PlayerPack>[];
  List<DiamondProduct> _diamondProducts = <DiamondProduct>[];
  List<ConsumableProduct> _consumableProducts = <ConsumableProduct>[];
  List<Map<String, dynamic>> _standings = <Map<String, dynamic>>[];
  Map<String, dynamic>? _seasonState;
  Tactics? _tactics;

  List<FinancialTransaction> _financialTransactions = <FinancialTransaction>[];
  bool _isLoadingTransactions = false;
  String? _transactionsErrorMessage;

  List<TransferHistoryEntry> _transferHistory = <TransferHistoryEntry>[];
  bool _isLoadingTransferHistory = false;
  String? _transferHistoryErrorMessage;

  bool _isLoading = false;
  bool _isBusy = false;
  bool _isSyncing = false;

  // Realtime / helper fields
  bool _useDebugFixtures = false;
  dynamic? _supabase;
  dynamic? _transferChannel;

  bool get _canUseSupabase => _isSupabaseReady;

  // expose repository for admin screens
  GameRepository get repo => _repository;

  // Financial / season getters
  List<FinancialTransaction> get financialTransactions =>
      List.unmodifiable(_financialTransactions);
  bool get isLoadingTransactions => _isLoadingTransactions;
  String? get transactionsErrorMessage => _transactionsErrorMessage;

  List<TransferHistoryEntry> get transferHistory => List.unmodifiable(_transferHistory);
  bool get isLoadingTransferHistory => _isLoadingTransferHistory;
  String? get transferHistoryErrorMessage => _transferHistoryErrorMessage;

  List<Bank> _banks = <Bank>[];
  List<BankDeposit> _bankDeposits = <BankDeposit>[];
  bool _isLoadingBanks = false;

  List<Bank> get banks => List.unmodifiable(_banks);
  List<BankDeposit> get bankDeposits => List.unmodifiable(_bankDeposits);
  bool get isLoadingBanks => _isLoadingBanks;

  Future<void> loadBankData() async {
    final activeClub = _activeClub;
    if (activeClub == null) {
      _banks = <Bank>[];
      _bankDeposits = <BankDeposit>[];
      return;
    }
    _isLoadingBanks = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repository.loadBanks(),
        _repository.loadBankDeposits(activeClub.id),
      ]);
      _banks = results[0] as List<Bank>;
      _bankDeposits = results[1] as List<BankDeposit>;
    } finally {
      _isLoadingBanks = false;
      notifyListeners();
    }
  }

  Future<void> depositToBank({required String bankId, required int amount}) async {
    try {
      await _repository.depositToBank(bankId: bankId, amount: amount);
      await loadBankData();
      final refreshedClub = await _repository.loadActiveClub(clubId: _activeClub?.id);
      if (refreshedClub != null) _activeClub = refreshedClub;
      notifyListeners();
    } catch (error) {
      throw Exception(_formatClubActionError(error));
    }
  }

  Future<void> withdrawFromBank({required String depositId}) async {
    try {
      final updatedClub = await _repository.withdrawFromBank(depositId: depositId);
      if (updatedClub != null) _activeClub = updatedClub;
      await loadBankData();
      notifyListeners();
    } catch (error) {
      throw Exception(_formatClubActionError(error));
    }
  }

  Future<void> loadTransferHistory() async {
    final activeClub = _activeClub;
    if (activeClub == null) {
      _transferHistory = <TransferHistoryEntry>[];
      return;
    }
    _isLoadingTransferHistory = true;
    _transferHistoryErrorMessage = null;
    notifyListeners();

    try {
      _transferHistory = await _repository.loadTransferHistory(activeClub.id);
    } catch (e) {
      _transferHistory = <TransferHistoryEntry>[];
      _transferHistoryErrorMessage = 'Transfer geçmişi yüklenemedi. Lütfen internet bağlantınızı kontrol edip tekrar deneyin.';
    } finally {
      _isLoadingTransferHistory = false;
      notifyListeners();
    }
  }

  Map<String, dynamic>? get seasonState => _seasonState;
  List<Map<String, dynamic>> get standings => List.unmodifiable(_standings);

  /// Same shape as performanceMultiplier in
  /// supabase/functions/_shared/match_engine.ts - kept in sync so the
  /// pre-match income estimate matches what the server will actually pay
  /// out. Looks up the active club's own row in the already-loaded
  /// standings list.
  double _performanceMultiplier() {
    final club = _activeClub;
    if (club == null) return 1.0;
    final row = _standings.cast<Map<String, dynamic>?>().firstWhere(
          (s) => (s?['club'] as Map<String, dynamic>?)?['id'] == club.id,
          orElse: () => null,
        );
    if (row == null) return 1.0;
    final wins = (row['wins'] as num?)?.toInt() ?? 0;
    final draws = (row['draws'] as num?)?.toInt() ?? 0;
    final played = (row['played'] as num?)?.toInt() ?? 0;
    if (played <= 0) return 1.0;
    final winRate = (wins + draws * 0.5) / played;
    final sampleWeight = (played / 5).clamp(0, 1);
    final raw = 0.7 + winRate * 0.6;
    return 1.0 + (raw - 1.0) * sampleWeight;
  }

  /// Calculate match economy summary for UI
  // supabase/functions/_shared/match_engine.ts'teki computeClubEconomy ile
  // aynı formülleri kullanır (stadyum geliri = kapasite*biletFiyatı/3,
  // sadece ev sahibi maçlarında; berabere +100 GP bonus; lig performansına
  // göre ölçeklenen çarpan) - önceden capacity/10 kullanıyordu (sunucudan
  // 3.33 kat düşük) ve deplasman senaryosunu hiç ayırt etmiyordu,
  // gerçekleşenle tutarsız bir tahmin gösteriyordu.
  Map<String, int> calculateMatchEconomy({required bool isWin, bool isDraw = false, bool isHome = true}) {
    final club = _activeClub;
    if (club == null) {
      return {
        'stadiumRevenue': 0,
        'sponsorRevenue': 0,
        'matchBonus': 0,
        'playerWages': 0,
        'maintenanceCost': 0,
        'totalRevenue': 0,
        'totalExpense': 0,
        'netIncome': 0,
      };
    }

    final perfMultiplier = _performanceMultiplier();
    final stadiumRevenue = isHome ? (((club.stadiumCapacity * club.ticketPrice) / 3) * perfMultiplier).round() : 0;
    final sponsorRevenue = (club.sponsorLevel * 500 * perfMultiplier).round();
    final matchBonus = isWin ? 300 : (isDraw ? 100 : -200);

    int playerWages = 0;
    for (final player in _squadPlayers) {
      playerWages += (player.currentAbility * 2).toInt();
    }

    final maintenanceCost = (club.stadiumCapacity ~/ 200) +
        (club.trainingFacilityLevel * 25);

    final totalRevenue = stadiumRevenue + sponsorRevenue + matchBonus;
    final totalExpense = playerWages + maintenanceCost;
    final netIncome = totalRevenue - totalExpense;

    return {
      'stadiumRevenue': stadiumRevenue,
      'sponsorRevenue': sponsorRevenue,
      'matchBonus': matchBonus,
      'playerWages': playerWages,
      'maintenanceCost': maintenanceCost,
      'totalRevenue': totalRevenue,
      'totalExpense': totalExpense,
      'netIncome': netIncome,
    };
  }

  /// Every club the current user owns (up to 4, one per league). Populated
  /// alongside the active club so a league-switcher UI can list them.
  List<ClubInfo> get myClubs => List.unmodifiable(_myClubs);
  List<ClubInfo> _myClubs = <ClubInfo>[];

  /// Switches the active club to [clubId] (must be one of [myClubs]) and
  /// reloads all club-scoped state (squad, fixtures, transfer market, etc.)
  /// for it. Used by the league picker to re-enter a different league
  /// without a full logout/login.
  Future<void> switchActiveClub(String clubId) async {
    await refreshGameState(activeClubId: clubId);
  }

  Future<void> refreshGameState({String? activeClubId}) async {
    if (!_canUseSupabase && _repository is SupabaseRepository) {
      _activeClub = null;
      _profile = null;
      _squadPlayers = <PlayerFM>[];
      _inboxMessages = <InboxMessage>[];
      _transferMarketItems = <TransferMarketItem>[];
      _freeAgents = <PlayerFM>[];
      _incomingTransferOffers = <TransferOffer>[];
      _outgoingTransferOffers = <TransferOffer>[];
      _fixtures = <MatchFixture>[];
      _results = <MatchResult>[];
      _standings = <Map<String, dynamic>>[];
      _seasonState = null;
      _tactics = null;
      _setLoading(false);
      return;
    }

    _setLoading(true);
    try {
      await _loadActiveClub(clubId: activeClubId);
      _myClubs = await _repository.loadMyClubs();

      await _loadUserProfile();
      await Future.wait(<Future<void>>[
        _loadSquadPlayers(),
        _loadInboxMessages(),
        _loadTransferMarket(),
        _loadFreeAgents(),
        _loadTransferOffers(),
        _loadFixturesAndResults(),
        _loadFinancialTransactions(),
        _loadMarketCatalog(),
      ]);
    } catch (error) {
      debugPrint('GameProvider refresh failed: $error');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadUserProfile() async {
    _profile = await _repository.loadProfile();
    try {
      _isAdmin = await _repository.isAdmin();
    } catch (_) {
      _isAdmin = false;
    }
  }

  Future<void> updateUsername(String username) async {
    final updated = await _repository.updateUsername(username);
    if (updated != null) {
      _profile = updated;
      notifyListeners();
    }
  }

  /// Cihazdan seçilen fotoğrafı Supabase Storage'a yükler ve profildeki
  /// avatar_url'i günceller.
  Future<void> uploadAndSetAvatar(List<int> bytes, String fileExtension) async {
    final url = await _repository.uploadAvatarImage(bytes, fileExtension);
    final updated = await _repository.updateAvatarUrl(url);
    if (updated != null) {
      _profile = updated;
      notifyListeners();
    }
  }

  /// [achievement] ("100_wins" | "win_streak_10") başarımının elmas ödülünü
  /// talep eder; eşik henüz karşılanmadıysa veya zaten alınmışsa hata fırlatır.
  Future<void> claimAchievementReward(String achievement) async {
    final updated = await _repository.claimAchievementReward(achievement);
    if (updated != null) {
      _profile = updated;
      notifyListeners();
    }
  }

  /// Haftalık 7 günlük giriş serisinin bugünkü ödülünü talep eder; gün
  /// 1-6 GP, gün 7 elmas verir. Dönen map: {day, gp_awarded, diamonds_awarded}.
  Future<Map<String, dynamic>> claimDailyLoginReward() async {
    final result = await _repository.claimDailyLoginReward(clubId: _activeClub?.id);
    await refreshGameState();
    return result;
  }

  /// [platform] ("instagram" | "x" | "tiktok" | "engagement") için tek
  /// seferlik sosyal medya ödülünü talep eder.
  Future<void> claimSocialReward(String platform) async {
    final updated = await _repository.claimSocialReward(platform);
    if (updated != null) {
      _profile = updated;
      notifyListeners();
    }
  }

  Future<void> _loadActiveClub({String? clubId}) async {
    _activeClub = await _repository.loadActiveClub(clubId: clubId);
  }

  Future<void> _loadSquadPlayers() async {
    final activeClub = _activeClub;
    if (activeClub == null) {
      _squadPlayers = <PlayerFM>[];
      return;
    }

    _squadPlayers = await _repository.loadSquadPlayers(activeClub.id);
  }

  /// Resolves a player by id for deep-linking into their card (e.g. from an
  /// inbox message's related_player_id) - checks the already-loaded squad
  /// first to avoid a round-trip for the common case, falls back to a
  /// direct lookup otherwise.
  Future<PlayerFM?> loadPlayerById(String playerId) async {
    for (final p in _squadPlayers) {
      if (p.id == playerId) return p;
    }
    try {
      return await _repository.loadPlayerById(playerId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadFinancialTransactions() async {
    final activeClub = _activeClub;
    if (activeClub == null) {
      _financialTransactions = <FinancialTransaction>[];
      return;
    }
    _isLoadingTransactions = true;
    _transactionsErrorMessage = null;
    notifyListeners();

    try {
      _financialTransactions = await _repository.loadFinancialTransactions(activeClub.id);
    } catch (e) {
      // Show friendly message for users, detailed info reported via ErrorReportingService
      _financialTransactions = <FinancialTransaction>[];
      _transactionsErrorMessage = 'Bütçe hareketleri yüklenemedi. Lütfen internet bağlantınızı kontrol edip tekrar deneyin.';
    } finally {
      _isLoadingTransactions = false;
      notifyListeners();
    }
  }

  Future<PlayerFM?> startPlayerDevelopment({required String playerId}) async {
    final updatedPlayer = await _repository.startPlayerDevelopment(playerId: playerId);

    if (updatedPlayer != null) {
      final index = _squadPlayers.indexWhere((player) => player.id == playerId);
      if (index >= 0) {
        _squadPlayers[index] = updatedPlayer;
        notifyListeners();
      }
    }

    return updatedPlayer;
  }

  /// Ödüllü reklam izlendikten sonra bir oyuncu gelişiminin kalan süresini
  /// %25 kısaltır (birikimli, gelişim başına en fazla 2 kez).
  Future<PlayerFM?> reducePlayerDevelopmentTimeWithAd({required String playerId}) async {
    final updatedPlayer = await _repository.reducePlayerDevelopmentTimeWithAd(playerId: playerId);

    if (updatedPlayer != null) {
      final index = _squadPlayers.indexWhere((player) => player.id == playerId);
      if (index >= 0) {
        _squadPlayers[index] = updatedPlayer;
        notifyListeners();
      }
    }

    return updatedPlayer;
  }

  Future<void> _loadInboxMessages() async {
    _inboxMessages = await _repository.loadInboxMessages();
  }

  Future<InboxMessage?> _createInboxMessage(String title, String body) async {
    final message = await _repository.addInboxMessage(
      title: title,
      body: body,
    );

    if (message != null) {
      _inboxMessages.insert(0, message);
      notifyListeners();
    }

    return message;
  }

  Future<void> _loadTransferMarket() async {
    _setSyncing(true);
    try {
      _transferMarketItems = await _repository.loadTransferMarket();
    } finally {
      _setSyncing(false);
    }
  }

  Future<void> _loadFreeAgents() async {
    _freeAgents = await _repository.loadFreeAgents();
  }

  Future<void> _loadTransferOffers() async {
    final clubId = _activeClub?.id;
    if (clubId == null) {
      _incomingTransferOffers = <TransferOffer>[];
      _outgoingTransferOffers = <TransferOffer>[];
      return;
    }
    final results = await Future.wait([
      _repository.loadIncomingTransferOffers(clubId),
      _repository.loadOutgoingTransferOffers(clubId),
    ]);
    _incomingTransferOffers = results[0];
    _outgoingTransferOffers = results[1];
  }

  Future<void> _loadMarketCatalog() async {
    final results = await Future.wait([
      _repository.loadPlayerPacks(),
      _repository.loadDiamondProducts(),
      _repository.loadConsumableProducts(),
    ]);
    _playerPacks = results[0] as List<PlayerPack>;
    _diamondProducts = results[1] as List<DiamondProduct>;
    _consumableProducts = results[2] as List<ConsumableProduct>;
  }

  Future<void> _loadFixturesAndResults() async {
    final now = DateTime.now();
    final activeClub = _activeClub;
    if (activeClub != null) {
      // Try to load saved tactics from DB first
      try {
        final saved = await _repository.loadTactics(activeClub.id);
        if (saved != null) {
          _tactics = saved;
        } else {
          final defaultPlayer =
              _squadPlayers.isNotEmpty ? _squadPlayers.first.id : '';
          _tactics = Tactics(
            clubId: activeClub.id,
            captainId: defaultPlayer,
            penaltyTakerId: defaultPlayer,
          );
        }
      } catch (e) {
        debugPrint('Failed to load saved tactics: $e');
        final defaultPlayer =
            _squadPlayers.isNotEmpty ? _squadPlayers.first.id : '';
        _tactics = Tactics(
          clubId: activeClub.id,
          captainId: defaultPlayer,
          penaltyTakerId: defaultPlayer,
        );
      }
    }

    if (activeClub != null) {
      try {
        final rows = await _repository.loadFixturesForClub(activeClub.id);
        final seasonData =
            await _repository.loadCurrentSeasonState(activeClub.id);
        if (seasonData != null) {
          _seasonState = seasonData;
          final standings =
              seasonData['standings'] as List<dynamic>? ?? <dynamic>[];
          _standings = standings.cast<Map<String, dynamic>>();
        } else {
          _seasonState = null;
          _standings = <Map<String, dynamic>>[];
        }

        if (rows.isEmpty) {
          if (_useDebugFixtures) {
            _fixtures = _buildDebugFixtures(now);
          } else {
            _fixtures = const <MatchFixture>[];
          }
          return;
        }

        _fixtures = rows.map((r) {
          final homeId = r['home_club_id'] as String?;
          final awayId = r['away_club_id'] as String?;
          final isHome = homeId == activeClub.id;
          final opponentClub = isHome ? r['away_club'] : r['home_club'];
          final opponentName = (opponentClub is Map ? opponentClub['name'] as String? : null) ?? 'Rakip';
          final opponentUsername = opponentClub is Map ? opponentClub['username'] as String? : null;
          final kickoff = DateTime.tryParse(r['match_date'] as String? ?? '') ??
              now.add(const Duration(days: 3));
          final opponentClubId = isHome ? awayId : homeId;
          return MatchFixture(
            id: r['id'] as String? ?? UniqueKey().toString(),
            opponentName: opponentName,
            opponentUsername: opponentUsername,
            opponentClubId: opponentClubId,
            kickoff: kickoff,
            isHome: isHome,
            status:
                (r['is_played'] as bool? ?? false) ? 'Tamamlandı' : 'Yaklaşan',
            homeScore: r['home_score'] as int? ?? 0,
            awayScore: r['away_score'] as int? ?? 0,
            week: (r['week'] as num?)?.toInt() ?? 1,
          );
        }).toList();
      } catch (e) {
        debugPrint('Failed to load fixtures from repo: $e');
        if (_useDebugFixtures) {
          _fixtures = _buildDebugFixtures(now);
        } else {
          _fixtures = const <MatchFixture>[];
        }
      }
    } else {
      _fixtures = const <MatchFixture>[];
    }

    // results remain local history; keep existing in-memory results
    if (_results.isEmpty) {
      _results = <MatchResult>[];
    }

    _checkUpcomingMatchAlerts(now);
  }

  // Session-local guard against re-notifying for the same fixture on every
  // refresh tick while the app stays open - the server's
  // pre_match_alert_sent flag is the durable/cross-session guard, this is
  // just to stop the in-app local notification from repeating every 20s.
  final Set<String> _alertedFixtureIds = <String>{};

  /// Re-checks already-loaded fixtures for the 30-minutes-to-kickoff
  /// window without re-fetching from the server - cheap enough to call
  /// from a short-interval app-wide timer (see RootShell) so the alert
  /// fires even while the user is on a screen that doesn't otherwise
  /// refresh fixtures (e.g. Dashboard).
  void checkUpcomingMatchAlertsNow() => _checkUpcomingMatchAlerts(DateTime.now());

  void _checkUpcomingMatchAlerts(DateTime now) {
    for (final fixture in _fixtures) {
      if (fixture.status == 'Tamamlandı') continue;
      if (_alertedFixtureIds.contains(fixture.id)) continue;

      final remaining = fixture.kickoff.difference(now);
      if (remaining <= const Duration(minutes: 30) && remaining > const Duration(minutes: 25)) {
        _alertedFixtureIds.add(fixture.id);
        NotificationService.instance.sendNotification(
          'Kritik Maç Yaklaşıyor',
          'Kritik maç 30 dakika içinde başlıyor! Kadronu son kez kontrol et.',
        );
      }
    }
  }

  List<MatchFixture> _buildDebugFixtures(DateTime now) {
    return List<MatchFixture>.generate(
      3,
      (index) {
        final matchDate = now.add(Duration(days: 2 + index * 3));
        return MatchFixture(
          id: 'debug-fixture-${index + 1}',
          opponentName: 'Debug Rakip ${index + 1}',
          kickoff: matchDate,
          isHome: index.isEven,
          status: 'Yaklaşan',
          homeScore: 0,
          awayScore: 0,
        );
      },
    );
  }

  Future<List<LeagueClubOption>> previewLeagueTheme(String theme) async {
    try {
      return await _repository.previewLeagueTheme(theme);
    } catch (error) {
      throw Exception(_formatClubActionError(error));
    }
  }

  Future<List<LeagueClubOption>> previewLeagueByCode(String invitationCode) async {
    if (invitationCode.trim().isEmpty) {
      throw Exception('Davet kodu boş olamaz.');
    }
    try {
      return await _repository.previewLeagueByCode(invitationCode);
    } catch (error) {
      throw Exception(_formatClubActionError(error));
    }
  }

  Future<OpponentScoutReport> scoutOpponent(String matchId) async {
    try {
      return await _repository.scoutOpponent(matchId);
    } catch (error) {
      throw Exception(_formatClubActionError(error));
    }
  }

  Future<void> selectClubForLeague(String clubId) async {
    try {
      final club = await _repository.selectClubForLeague(clubId);
      if (club != null) {
        try {
          AnalyticsService.instance.logEvent('select_club', parameters: {'club_id': clubId});
        } catch (_) {}
        await refreshGameState(activeClubId: club.id);
        return;
      }

      throw Exception('Kulüp seçilemedi.');
    } catch (error) {
      throw Exception(_formatClubActionError(error));
    }
  }

  Future<void> joinLeagueWithCode(String invitationCode) async {
    if (invitationCode.trim().isEmpty) {
      throw Exception('Davet kodu boş olamaz.');
    }

    try {
      final club = await _repository.joinLeagueWithCode(invitationCode);
      if (club != null) {
        try {
          AnalyticsService.instance.logEvent('join_league');
        } catch (_) {}
        await refreshGameState(activeClubId: club.id);
        return;
      }

      throw Exception('Lige katılamadı.');
    } catch (error) {
      throw Exception(_formatClubActionError(error));
    }
  }

  /// Mevcut kulübü bırakır. Kulüp silinmez, sahipsiz (bot) hale gelir ve
  /// başka biri tarafından katılınabilir olur. Yerel durumu tamamen
  /// temizler; çağıran taraf kullanıcıyı lig oluştur/katıl ekranına
  /// yönlendirmelidir.
  Future<void> leaveClub({String? clubId}) async {
    try {
      await _repository.leaveCurrentClub(clubId: clubId ?? _activeClub?.id);
    } catch (error) {
      throw Exception(_formatClubActionError(error));
    }

    _activeClub = null;
    _squadPlayers = <PlayerFM>[];
    _fixtures = <MatchFixture>[];
    _results = <MatchResult>[];
    _transferMarketItems = <TransferMarketItem>[];
    _freeAgents = <PlayerFM>[];
    _incomingTransferOffers = <TransferOffer>[];
    _outgoingTransferOffers = <TransferOffer>[];
    _standings = <Map<String, dynamic>>[];
    _seasonState = null;
    _tactics = null;
    _financialTransactions = <FinancialTransaction>[];
    _transferHistory = <TransferHistoryEntry>[];
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    try {
      await _repository.deleteAccount();
    } catch (error) {
      throw Exception(_formatClubActionError(error));
    }

    _activeClub = null;
    _profile = null;
    _squadPlayers = <PlayerFM>[];
    _fixtures = <MatchFixture>[];
    _results = <MatchResult>[];
    _transferMarketItems = <TransferMarketItem>[];
    _freeAgents = <PlayerFM>[];
    _incomingTransferOffers = <TransferOffer>[];
    _outgoingTransferOffers = <TransferOffer>[];
    _standings = <Map<String, dynamic>>[];
    _seasonState = null;
    _tactics = null;
    _financialTransactions = <FinancialTransaction>[];
    _transferHistory = <TransferHistoryEntry>[];
    notifyListeners();
  }

  String _formatClubActionError(Object error) {
    final message = error.toString();
    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }
    return message;
  }

  /// Preview-only local simulation for UI/testing purposes.
  /// Production match results must come from the server-side edge function.
  Future<MatchResult> previewMatchOutcomeForUI({
    required String homeTeamName,
    required String awayTeamName,
    required List<PlayerFM> homeSquad,
    required List<PlayerFM> awaySquad,
    required Tactics homeTactics,
    required Tactics awayTactics,
  }) async {
    return _matchRepository.simulateMatch(
      homeTeamId: _activeClub?.id ?? 'home',
      awayTeamId: 'away',
      homeTeamName: homeTeamName,
      awayTeamName: awayTeamName,
      homeSquad: homeSquad,
      awaySquad: awaySquad,
      homeTactics: homeTactics,
      awayTactics: awayTactics,
    );
  }

  Future<MatchResult> playNextFixture() async {
    final activeClub = _activeClub;
    if (activeClub == null) throw Exception('Aktif kulüp bulunamadı.');
    if (_fixtures.isEmpty) throw Exception('Oynanacak maç bulunmuyor.');

    final fixture = _fixtures.first;
    final result = await _repository.playNextFixture();
    if (result == null) {
      throw Exception('Maç sonucu alınamadı. Lütfen tekrar deneyin.');
    }

    _results.insert(0, result);

    // Match result, economy and inbox are authoritative on the server.
    await _loadActiveClub();
    await _loadSquadPlayers();
    await _loadInboxMessages();
    await _loadFixturesAndResults();

    notifyListeners();
    await (_notificationSender?.call(
          'Maç Sonucu',
          '${activeClub.name} ${result.homeScore} - ${result.awayScore} ${fixture.opponentName}',
        ) ??
        NotificationService.instance.sendNotification(
          'Maç Sonucu',
          '${activeClub.name} ${result.homeScore} - ${result.awayScore} ${fixture.opponentName}',
        ));
    try {
      AnalyticsService.instance.logEvent('play_match', parameters: {
        'opponent': fixture.opponentName,
        'home_score': result.homeScore,
        'away_score': result.awayScore,
      });
    } catch (_) {}
    return result;
  }

  List<PlayerFM> _generateOpponentSquad() {
    return List<PlayerFM>.generate(
      11,
      (index) => PlayerFM(
        id: 'away-player-$index',
        clubId: 'away',
        name: 'Rakip Oyuncu ${index + 1}',
        position: 'Mevki ${index + 1}',
        age: 25 + (index % 5),
        currentAbility: 60 + index,
        potentialAbility: 70 + index,
        morale: 75,
        fitness: 90,
        finishing: 50,
        passing: 50,
        tackling: 50,
        composure: 50,
        determination: 50,
        consistency: 50,
        injuryProneness: 5,
      ),
    );
  }

  void _initRealtimeStreams() {
    // Realtime subscription for transfer market changes.
    // Implementation depends on supabase_flutter version and Realtime API.
    // TODO: Update when Realtime API is stable in the current supabase_flutter version.
  }

  void _upsertTransferMarketItem(TransferMarketItem item) {
    final items = List<TransferMarketItem>.from(_transferMarketItems);
    final index = items.indexWhere((element) => element.id == item.id);

    if (index >= 0) {
      items[index] = item;
    } else {
      items.add(item);
    }

    _transferMarketItems = items;
    notifyListeners();
  }

  Future<void> listPlayerForTransfer({required String playerId, required int askingPrice}) async {
    if (_repository.currentUserId == null) {
      throw Exception('Kullanıcı oturumu bulunamadı.');
    }

    if (_isBusy) return;

    _setBusy(true);
    try {
      final item = await _repository.listPlayerForTransfer(playerId: playerId, askingPrice: askingPrice);
      if (item != null) {
        try {
          AnalyticsService.instance.logEvent('transfer_listed', parameters: {
            'player_id': playerId,
            'asking_price': askingPrice,
          });
        } catch (_) {}
        _upsertTransferMarketItem(item);
      }
    } finally {
      _setBusy(false);
    }
  }

  Future<void> withdrawTransferListing({required String playerId}) async {
    if (_repository.currentUserId == null) {
      throw Exception('Kullanıcı oturumu bulunamadı.');
    }

    if (_isBusy) return;

    _setBusy(true);
    try {
      await _repository.withdrawTransferListing(playerId: playerId);
      _transferMarketItems = List<TransferMarketItem>.from(_transferMarketItems)
        ..removeWhere((item) => item.playerId == playerId);
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  /// Bir oyuncu için gerçek transfer teklifi gönderir (açık artırma değil).
  /// Oyuncu bir kulübe aitse, o kulüp (gerçek kullanıcı ya da bot) teklifi
  /// kabul/red edecek. Teklif bloke edilen bütçeyle (blocked_budget) güvence
  /// altına alınır.
  Future<void> makeTransferOffer({required String playerId, required int offerAmount}) async {
    if (_activeClub == null) throw Exception('Aktif kulüp bulunamadı.');
    if (_isBusy) return;

    _setBusy(true);
    try {
      final offer = await _repository.makeTransferOffer(playerId: playerId, offerAmount: offerAmount);
      try {
        AnalyticsService.instance.logEvent('transfer_offer_made', parameters: {
          'player_id': playerId,
          'offer_amount': offerAmount,
        });
      } catch (_) {}
      await refreshGameState();
      // Bot clubs resolve immediately - surface a rejection now rather
      // than waiting for the player to check their inbox.
      if (offer != null && offer.status == 'rejected') {
        throw Exception('Teklif reddedildi.');
      }
    } finally {
      _setBusy(false);
    }
  }

  /// Kendi oyuncuna gelen bir teklifi kabul veya reddeder.
  Future<void> respondToTransferOffer({required String offerId, required bool accept}) async {
    if (_isBusy) return;
    _setBusy(true);
    try {
      await _repository.respondToTransferOffer(offerId: offerId, accept: accept);
      await refreshGameState();
    } finally {
      _setBusy(false);
    }
  }

  /// Gönderdiğin bekleyen bir teklifi geri çeker, bloke edilen bütçe serbest kalır.
  Future<void> withdrawTransferOffer({required String offerId}) async {
    if (_isBusy) return;
    _setBusy(true);
    try {
      await _repository.withdrawTransferOffer(offerId: offerId);
      await refreshGameState();
    } finally {
      _setBusy(false);
    }
  }

  /// Serbest (kulüpsüz) bir oyuncuyu doğrudan, pazarlıksız satın alır.
  Future<void> signFreeAgent({required String playerId}) async {
    if (_activeClub == null) throw Exception('Aktif kulüp bulunamadı.');
    if (_isBusy) return;

    _setBusy(true);
    try {
      final updatedClub = await _repository.signFreeAgent(playerId: playerId);
      if (updatedClub != null) {
        _activeClub = updatedClub;
      }
      try {
        AnalyticsService.instance.logEvent('sign_free_agent', parameters: {'player_id': playerId});
      } catch (_) {}
      await refreshGameState();
    } finally {
      _setBusy(false);
    }
  }

  /// [packId]'ye karşılık gelen oyuncu paketini elmasla açar; oluşan
  /// oyuncuları döndürür (paket açılış ekranında göstermek için).
  Future<List<PlayerFM>> openPlayerPack({required String packId}) async {
    if (_activeClub == null) throw Exception('Aktif kulüp bulunamadı.');
    if (_isBusy) return <PlayerFM>[];

    _setBusy(true);
    try {
      final newPlayers = await _repository.openPlayerPack(packId: packId);
      try {
        AnalyticsService.instance.logEvent('open_player_pack', parameters: {'pack_id': packId});
      } catch (_) {}
      await refreshGameState();
      return newPlayers;
    } finally {
      _setBusy(false);
    }
  }

  /// Elmas karşılığı taktik gizleme veya kamp hakkı satın alır.
  Future<void> purchaseConsumable({required String productId}) async {
    if (_activeClub == null) throw Exception('Aktif kulüp bulunamadı.');
    if (_isBusy) return;

    _setBusy(true);
    try {
      await _repository.purchaseConsumable(productId: productId, clubId: _activeClub!.id);
      try {
        AnalyticsService.instance.logEvent('purchase_consumable', parameters: {'product_id': productId});
      } catch (_) {}
      await refreshGameState();
    } finally {
      _setBusy(false);
    }
  }

  /// Kulübün bir sonraki maçı için taktiklerini rakipten gizler.
  Future<void> hideTacticsForNextMatch() async {
    if (_activeClub == null) throw Exception('Aktif kulüp bulunamadı.');
    if (_isBusy) return;

    _setBusy(true);
    try {
      await _repository.hideTacticsForNextMatch(clubId: _activeClub!.id);
      try {
        AnalyticsService.instance.logEvent('hide_tactics_for_next_match');
      } catch (_) {}
      await refreshGameState();
    } finally {
      _setBusy(false);
    }
  }

  /// Takımı bir sonraki maç için kampa gönderir (%5 performans bonusu).
  Future<void> sendTeamToCamp() async {
    if (_activeClub == null) throw Exception('Aktif kulüp bulunamadı.');
    if (_isBusy) return;

    _setBusy(true);
    try {
      await _repository.sendTeamToCamp(clubId: _activeClub!.id);
      try {
        AnalyticsService.instance.logEvent('send_team_to_camp');
      } catch (_) {}
      await refreshGameState();
    } finally {
      _setBusy(false);
    }
  }

  /// StoreKit satın alımı tamamlandıktan sonra makbuzu sunucuda doğrular
  /// ve elmas bakiyesini günceller. Asla client tarafında elmas eklemez -
  /// bakiye yalnızca Apple'dan gerçekten doğrulanmış bir işlemden sonra artar.
  Future<void> creditDiamondsFromPurchase({
    required String receiptData,
    required String productId,
    required String transactionId,
  }) async {
    await _repository.verifyIapPurchase(
      receiptData: receiptData,
      productId: productId,
      transactionId: transactionId,
    );
    await _loadUserProfile();
    notifyListeners();
  }

  /// Bilet fiyatını günceller. Anında uygulanır (inşaat gerektirmez).
  /// Stadyum kapasitesi, tesis seviyesi veya bilet fiyatı için zamanlı bir
  /// geliştirme başlatır. [upgradeType] 'stadium', 'facility' veya
  /// 'ticket_price' olmalı. Kulüp başına aynı anda tek bir geliştirme
  /// sürebilir; tamamlanma sunucu tarafında (cron) uygulanır, uygulama
  /// kapalı olsa bile ilerler.
  Future<void> startClubDevelopment({required String upgradeType, required int targetValue}) async {
    final activeClub = _activeClub;
    if (activeClub == null) throw Exception('Aktif kulüp bulunamadı.');
    if (activeClub.isDevelopmentUpgrading) {
      throw Exception('Zaten sürmekte olan bir geliştirme var.');
    }
    if (_isBusy) return;

    _setBusy(true);
    try {
      final updatedClub = await _repository.startClubDevelopment(
        clubId: activeClub.id,
        upgradeType: upgradeType,
        targetValue: targetValue,
      );

      if (updatedClub != null) {
        _activeClub = updatedClub;
      }

      final completesAt = _activeClub?.developmentCompletesAt;
      final label = switch (upgradeType) {
        'stadium' => 'Stadyum genişletme',
        'facility' => 'Tesis yükseltmesi',
        _ => 'Bilet fiyatı güncellemesi',
      };
      await _createInboxMessage(
        label,
        completesAt != null
            ? '$label başlatıldı. Tahmini tamamlanma: ${completesAt.toLocal()}'
            : '$label başlatıldı.',
      );

      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  /// Ödüllü reklam izlendikten sonra süren kulüp geliştirmesinin (stadyum/
  /// tesis/bilet fiyatı) kalan süresini %25 kısaltır (birikimli, gelişim
  /// başına en fazla 2 kez).
  Future<void> reduceClubDevelopmentTimeWithAd() async {
    final activeClub = _activeClub;
    if (activeClub == null) throw Exception('Aktif kulüp bulunamadı.');

    final updatedClub = await _repository.reduceClubDevelopmentTimeWithAd(clubId: activeClub.id);
    if (updatedClub != null) {
      _activeClub = updatedClub;
      notifyListeners();
    }
  }

  /// Sponsor seviyesini yükseltmek için zamanlı bir yükseltme başlatır
  /// (1-5 arası). Tamamlanma sunucu tarafında (cron) uygulanır, uygulama
  /// kapalı olsa bile ilerler.
  Future<void> upgradeSponsor() async {
    final activeClub = _activeClub;
    if (activeClub == null) throw Exception('Aktif kulüp bulunamadı.');
    if (activeClub.sponsorLevel >= 5) {
      throw Exception('Sponsor maksimum seviyesi 5 olabilir.');
    }
    if (activeClub.isSponsorUpgrading) {
      throw Exception('Sponsor yükseltmesi zaten sürüyor.');
    }
    if (_isBusy) return;

    _setBusy(true);
    try {
      final updatedClub =
          await _repository.upgradeSponsor(clubId: activeClub.id);
      if (updatedClub != null) {
        _activeClub = updatedClub;
      }

      final completesAt = _activeClub?.sponsorUpgradeCompletesAt;
      await _createInboxMessage(
        'Sponsor Anlaşması',
        completesAt != null
            ? 'Sponsor yükseltmesi başlatıldı. Tahmini tamamlanma: ${completesAt.toLocal()}'
            : 'Sponsor yükseltmesi başlatıldı.',
      );

      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> saveTactics(Tactics tactics) async {
    final activeClub = _activeClub;
    if (activeClub == null) {
      _tactics = tactics;
      notifyListeners();
      return;
    }

    _setBusy(true);
    try {
      final saved = await _repository.saveTactics(activeClub.id, tactics);
      if (saved != null) {
        _tactics = saved;
      } else {
        // fallback to local
        _tactics = tactics;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to save tactics: $e');
      _tactics = tactics;
      notifyListeners();
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> markMessageAsRead(String messageId) async {
    final index =
        _inboxMessages.indexWhere((message) => message.id == messageId);
    if (index < 0) return;

    final message = _inboxMessages[index];
    if (message.isRead) return;

    final updated = await _repository.markMessageAsRead(messageId);
    if (!updated) return;

    _inboxMessages[index] = InboxMessage(
      id: message.id,
      title: message.title,
      body: message.body,
      isRead: true,
      createdAt: message.createdAt,
    );
    notifyListeners();
  }

  Future<void> markMessageAsUnread(String messageId) async {
    final index =
        _inboxMessages.indexWhere((message) => message.id == messageId);
    if (index < 0) return;

    final message = _inboxMessages[index];
    if (!message.isRead) return;

    final updated = await _repository.markMessageAsUnread(messageId);
    if (updated == null) return;

    _inboxMessages[index] = InboxMessage(
      id: message.id,
      title: message.title,
      body: message.body,
      isRead: false,
      createdAt: message.createdAt,
    );
    notifyListeners();
  }

  /// Puan durumu ekranından herhangi bir kulübün güncel kadrosunu getirir.
  Future<OpponentScoutReport> viewClubRoster(String clubId) {
    return _repository.viewClubRoster(clubId);
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  void _setBusy(bool value) {
    if (_isBusy == value) return;
    _isBusy = value;
    notifyListeners();
  }

  void _setSyncing(bool value) {
    if (_isSyncing == value) return;
    _isSyncing = value;
    notifyListeners();
  }

  void recordLastActivity() {
    // Offline activity tracking is handled on the server.
  }

  @override
  void dispose() {
    final transferChannel = _transferChannel;
    if (transferChannel != null) {
      transferChannel.unsubscribe();
    }
    super.dispose();
  }
}
