import 'package:flutter/material.dart';

import '../models/club_info.dart';
import '../models/inbox_message.dart';
import '../models/match_fixture.dart';
import '../models/match_result.dart';
import '../models/offline_simulation_result.dart';
import '../models/player_fm.dart';
import '../models/financial_transaction.dart';
import '../models/profile.dart';
import '../models/tactics.dart';
import '../models/transfer_market_item.dart';
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
  List<Map<String, dynamic>> _standings = <Map<String, dynamic>>[];
  Map<String, dynamic>? _seasonState;
  Tactics? _tactics;

  List<FinancialTransaction> _financialTransactions = <FinancialTransaction>[];
  bool _isLoadingTransactions = false;
  String? _transactionsErrorMessage;

  bool _isLoading = false;
  bool _isBusy = false;
  bool _isSyncing = false;

  // Realtime / helper fields
  final Map<String, String> _fixtureOpponentClubIds = {};
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

  Map<String, dynamic>? get seasonState => _seasonState;
  List<Map<String, dynamic>> get standings => List.unmodifiable(_standings);

  /// Calculate match economy summary for UI
  Map<String, int> calculateMatchEconomy({required bool isWin}) {
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

    final stadiumRevenue = (club.stadiumCapacity ~/ 10) * club.ticketPrice;
    final sponsorRevenue = club.sponsorLevel * 500;
    final matchBonus = isWin ? 300 : -200;

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

  Future<void> refreshGameState() async {
    if (!_canUseSupabase && _repository is SupabaseRepository) {
      _activeClub = null;
      _profile = null;
      _squadPlayers = <PlayerFM>[];
      _inboxMessages = <InboxMessage>[];
      _transferMarketItems = <TransferMarketItem>[];
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
      await _loadActiveClub();

      // Keep the club setup flow explicit for new users. When no active club is present,
      // the auth/setup screen should decide whether to create or claim a club.
      if (_activeClub != null) {
        try {
          await _repository.assignPlayersFromTeamIds();
        } catch (e) {
          debugPrint('assignPlayersFromTeamIds failed: $e');
        }
      }

      await _loadUserProfile();
      await Future.wait(<Future<void>>[
        _loadSquadPlayers(),
        _loadInboxMessages(),
        _loadTransferMarket(),
        _loadFixturesAndResults(),
        _loadFinancialTransactions(),
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

  Future<void> _loadActiveClub() async {
    _activeClub = await _repository.loadActiveClub();
  }

  Future<void> _loadSquadPlayers() async {
    final activeClub = _activeClub;
    if (activeClub == null) {
      _squadPlayers = <PlayerFM>[];
      return;
    }

    _squadPlayers = await _repository.loadSquadPlayers(activeClub.id);
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

  Future<PlayerFM?> applyPlayerDevelopmentToPlayer({
    required String playerId,
    required int minutesPlayed,
    required int trainingFacilityLevel,
    required int morale,
    required double formRating,
  }) async {
    final updatedPlayer = await _repository.advancePlayerDevelopment(
      playerId: playerId,
      minutesPlayed: minutesPlayed,
      trainingFacilityLevel: trainingFacilityLevel,
      morale: morale,
      formRating: formRating,
    );

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
          final opponentName = isHome
              ? (r['away_club'] is Map
                      ? (r['away_club']['name'] as String?)
                      : null) ??
                  'Rakip'
              : (r['home_club'] is Map
                      ? (r['home_club']['name'] as String?)
                      : null) ??
                  'Rakip';
          final kickoff = DateTime.tryParse(r['match_date'] as String? ?? '') ??
              now.add(const Duration(days: 3));
          final opponentClubId = isHome ? awayId : homeId;
          if (opponentClubId != null) {
            _fixtureOpponentClubIds[r['id'] as String? ?? UniqueKey().toString()] = opponentClubId;
          }
          return MatchFixture(
            id: r['id'] as String? ?? UniqueKey().toString(),
            opponentName: opponentName,
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

  Future<List<ClubInfo>> loadAvailableClubs() async {
    return _repository.loadAvailableClubs();
  }

  Future<void> createClub(String name) async {
    if (name.trim().isEmpty) {
      throw Exception('Kulüp adı boş olamaz.');
    }

    try {
      final club = await _repository.createClub(name);
      if (club != null) {
        _activeClub = club;
        try {
          AnalyticsService.instance.logEvent('create_club');
        } catch (_) {}
        await refreshGameState();
        return;
      }

      throw Exception('Kulüp oluşturulamadı.');
    } catch (error) {
      throw Exception(_formatClubActionError(error));
    }
  }

  Future<void> claimClub(String clubId) async {
    try {
      final club = await _repository.claimClub(clubId);
      if (club != null) {
        _activeClub = club;
        await refreshGameState();
        return;
      }

      throw Exception('Kulüp seçilemedi.');
    } catch (error) {
      throw Exception(_formatClubActionError(error));
    }
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

    items.sort((a, b) => a.endTime.compareTo(b.endTime));
    _transferMarketItems = items;
    notifyListeners();
  }

  Future<void> placeBid(
      {required String marketId, required int bidAmount}) async {
    if (_repository.currentUserId == null) {
      throw Exception('Kullanıcı oturumu bulunamadı.');
    }

    if (_isBusy) return;

    _setBusy(true);
    try {
      final updatedItem = await _repository.placeBid(marketId, bidAmount);
      if (updatedItem != null) {
        try {
          AnalyticsService.instance.logEvent('transfer_bid', parameters: {
            'market_id': marketId,
            'bid_amount': bidAmount,
          });
        } catch (_) {}
        _upsertTransferMarketItem(updatedItem);
        await _createInboxMessage(
          'Transfer Teklifi',
          'Transfer pazarında ${updatedItem.currentHighestBid} GP teklifiniz kabul edildi.',
        );
      }
    } finally {
      _setBusy(false);
    }
  }

  Future<void> acceptTransferOffer({required String playerId}) async {
    if (_activeClub == null) throw Exception('Aktif kulüp bulunamadı.');
    if (_isBusy) return;

    _setBusy(true);
    try {
      final updatedClub = await _repository.acceptTransferOffer(playerId: playerId);

      if (updatedClub != null) {
        _activeClub = updatedClub;
      }

      final inbox = await _repository.addInboxMessage(
        title: 'Transfer İşlemi',
        body: 'Transfer işlemi tamamlandı.',
      );
      if (inbox != null) {
        _inboxMessages.insert(0, inbox);
      }

      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> upgradeClub({int? stadiumCapacity, int? trainingFacilityLevel, int? ticketPrice}) async {
    final activeClub = _activeClub;
    if (activeClub == null) throw Exception('Aktif kulüp bulunamadı.');
    if (_isBusy) return;

    _setBusy(true);
    try {
      final updatedClub = await _repository.upgradeClub(
        clubId: activeClub.id,
        stadiumCapacity: stadiumCapacity,
        trainingFacilityLevel: trainingFacilityLevel,
        ticketPrice: ticketPrice,
      );

      if (updatedClub != null) {
        _activeClub = updatedClub;
      }

      final upgradeMessage = await _repository.addInboxMessage(
        title: 'Tesis Yükseltmesi',
        body: 'Yükseltme tamamlandı!',
      );
      if (upgradeMessage != null) {
        _inboxMessages.insert(0, upgradeMessage);
      }

      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  Future<OfflineSimulationResult> simulateOfflineMatches() async {
    if (_isBusy) {
      return OfflineSimulationResult(
        matchesSimulated: 0,
        totalIncome: 0,
        playersImproved: 0,
        transferOffersReceived: 0,
        inboxMessagesAdded: 0,
        offlineDuration: Duration.zero,
      );
    }

    try {
      await _repository.touchLastActivity();
      final result = await _repository.simulateOfflineProgress();

      await _loadActiveClub();
      await _loadInboxMessages();

      notifyListeners();
      return result;
    } catch (error) {
      debugPrint('simulateOfflineMatches failed: $error');
      return OfflineSimulationResult(
        matchesSimulated: 0,
        totalIncome: 0,
        playersImproved: 0,
        transferOffersReceived: 0,
        inboxMessagesAdded: 0,
        offlineDuration: Duration.zero,
      );
    }
  }

  /// Sponsor seviyesini yükselt (1-5 arası)
  Future<void> upgradeSponsor() async {
    final activeClub = _activeClub;
    if (activeClub == null) throw Exception('Aktif kulüp bulunamadı.');
    if (activeClub.sponsorLevel >= 5) {
      throw Exception('Sponsor maksimum seviyesi 5 olabilir.');
    }
    if (_isBusy) return;

    _setBusy(true);
    try {
      final updatedClub =
          await _repository.upgradeSponsor(clubId: activeClub.id);
      if (updatedClub != null) {
        _activeClub = updatedClub;
      }

      final sponsorLevel = _activeClub?.sponsorLevel ?? activeClub.sponsorLevel;
      await _createInboxMessage(
        'Sponsor Anlaşması',
        'Sponsor seviyesi $sponsorLevel\'ye yükseltildi! Yeni aylık gelir: ${sponsorLevel * 1000} GP',
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
