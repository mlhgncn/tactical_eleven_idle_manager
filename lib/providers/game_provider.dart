import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/club_info.dart';
import '../models/inbox_message.dart';
import '../models/match_fixture.dart';
import '../models/match_result.dart';
import '../models/player_fm.dart';
import '../models/profile.dart';
import '../models/tactics.dart';
import '../models/transfer_market_item.dart';
import '../repositories/match_repository.dart';
import '../repositories/repository_interface.dart';
import '../repositories/supabase_repository.dart';

class GameProvider extends ChangeNotifier {
  GameProvider({
    GameRepository? repository,
    MatchRepository? matchRepository,
    bool enableRealtime = true,
  })  : _repository = repository ?? SupabaseRepository(),
        _matchRepository = matchRepository ?? MatchRepository(),
        _enableRealtime = enableRealtime {
    if (_enableRealtime) {
      _initRealtimeStreams();
    }
  }

  final GameRepository _repository;
  final MatchRepository _matchRepository;
  final bool _enableRealtime;
  SupabaseClient get _supabase => Supabase.instance.client;
  RealtimeChannel? _transferChannel;

  ClubInfo? _activeClub;
  Profile? _profile;
  List<PlayerFM> _squadPlayers = <PlayerFM>[];
  List<InboxMessage> _inboxMessages = <InboxMessage>[];
  List<TransferMarketItem> _transferMarketItems = <TransferMarketItem>[];
  List<MatchFixture> _fixtures = <MatchFixture>[];
  List<MatchResult> _results = <MatchResult>[];
  Tactics? _tactics;
  bool _isLoading = false;
  bool _isBusy = false;
  bool _isSyncing = false;

  ClubInfo? get activeClub => _activeClub;
  Profile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;
  bool get isSyncing => _isSyncing;
  List<PlayerFM> get squadPlayers => List.unmodifiable(_squadPlayers);
  List<InboxMessage> get inboxMessages => List.unmodifiable(_inboxMessages);
  List<TransferMarketItem> get transferMarketItems => List.unmodifiable(_transferMarketItems);
  List<MatchFixture> get fixtures => List.unmodifiable(_fixtures);
  List<MatchResult> get results => List.unmodifiable(_results);
  Tactics? get tactics => _tactics;

  Future<void> refreshGameState() async {
    _setLoading(true);
    try {
      await _loadActiveClub();
      await _loadUserProfile();
      await Future.wait(<Future<void>>[
        _loadSquadPlayers(),
        _loadInboxMessages(),
        _loadTransferMarket(),
        _loadFixturesAndResults(),
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
  }

  Future<void> _loadActiveClub() async {
    _activeClub = await _repository.loadActiveClub();
  }

  Future<void> _loadSquadPlayers() async {
    if (_activeClub == null) {
      _squadPlayers = <PlayerFM>[];
      return;
    }

    _squadPlayers = await _repository.loadSquadPlayers(_activeClub!.id);
  }

  Future<void> _loadInboxMessages() async {
    _inboxMessages = await _repository.loadInboxMessages();
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
    if (_tactics == null && _activeClub != null) {
      final defaultPlayer = _squadPlayers.isNotEmpty ? _squadPlayers.first.id : '';
      _tactics = Tactics(
        clubId: _activeClub!.id,
        captainId: defaultPlayer,
        penaltyTakerId: defaultPlayer,
      );
    }

    _fixtures = List<MatchFixture>.generate(
      5,
      (index) {
        final matchDate = now.add(Duration(days: 2 + index * 3));
        return MatchFixture(
          id: 'fixture-${index + 1}',
          opponentName: 'Rakip ${index + 1}',
          kickoff: matchDate,
          isHome: index.isEven,
          status: 'Yaklaşan',
          homeScore: 0,
          awayScore: 0,
        );
      },
    );

    _results = List<MatchResult>.generate(
      4,
      (index) {
        final homeScore = index % 3 + 1;
        final awayScore = (index + 1) % 4;
        return MatchResult(
          homeTeamId: 'home',
          awayTeamId: 'away-${index + 1}',
          homeScore: homeScore,
          awayScore: awayScore,
          homeShots: 8 + index * 2,
          awayShots: 5 + index,
          homeXg: homeScore * 1.1,
          awayXg: awayScore * 0.9,
          homePossession: 50 + index,
          commentary: [
            'Maç başlangıcı',
            'Skor: $homeScore - $awayScore',
            'Maç bitti',
          ],
        );
      },
    );
  }

  Future<MatchResult> simulateMatch({
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

  void _initRealtimeStreams() {
    _transferChannel = _supabase.channel('realtime-transfer-market');
    _transferChannel!.on(
      RealtimeListenTypes.postgresChanges,
      ChannelFilter(event: '*', schema: 'public', table: 'transfer_market'),
      (payload, [ref]) {
        final record = payload.newRecord ?? payload.record;
        if (record == null) return;
        _upsertTransferMarketItem(TransferMarketItem.fromMap(Map<String, dynamic>.from(record as Map<String, dynamic>)));
      },
    );
    _transferChannel!.subscribe();
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

  Future<void> placeBid({required String marketId, required int bidAmount}) async {
    if (_repository.currentUserId == null) {
      throw Exception('Kullanıcı oturumu bulunamadı.');
    }

    if (_isBusy) return;

    _setBusy(true);
    try {
      final updatedItem = await _repository.placeBid(marketId, bidAmount);
      if (updatedItem != null) {
        _upsertTransferMarketItem(updatedItem);
      }
    } finally {
      _setBusy(false);
    }
  }

  Future<void> acceptTransferOffer({required String playerId, required int transferFee}) async {
    if (_activeClub == null) throw Exception('Aktif kulüp bulunamadı.');
    if (_isBusy) return;

    _setBusy(true);
    try {
      final newBudget = _activeClub!.budget - transferFee;
      if (newBudget < 0) throw Exception('Yeterli bütçe yok.');

      final updatedClub = await _repository.acceptTransferOffer(
        clubId: _activeClub!.id,
        newBudget: newBudget,
        playerId: playerId,
      );

      if (updatedClub != null) {
        _activeClub = updatedClub;
      } else {
        _activeClub = _activeClub!.copyWith(budget: newBudget);
      }

      _squadPlayers.removeWhere((player) => player.id == playerId);
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> upgradeClub({
    int? stadiumCapacity,
    int? trainingFacilityLevel,
    int? ticketPrice,
  }) async {
    if (_activeClub == null) throw Exception('Aktif kulüp bulunamadı.');
    if (_isBusy) return;

    _setBusy(true);
    try {
      final newBudget = _activeClub!.budget - 500;
      if (newBudget < 0) throw Exception('Yeterli bütçe yok.');

      final updatedClub = await _repository.upgradeClub(
        clubId: _activeClub!.id,
        stadiumCapacity: stadiumCapacity,
        trainingFacilityLevel: trainingFacilityLevel,
        ticketPrice: ticketPrice,
        budget: newBudget,
      );

      if (updatedClub != null) {
        _activeClub = updatedClub;
      } else {
        _activeClub = _activeClub!.copyWith(
          budget: newBudget,
          stadiumCapacity: stadiumCapacity ?? _activeClub!.stadiumCapacity,
          trainingFacilityLevel: trainingFacilityLevel ?? _activeClub!.trainingFacilityLevel,
          ticketPrice: ticketPrice ?? _activeClub!.ticketPrice,
        );
      }

      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> saveTactics(Tactics tactics) async {
    _tactics = tactics;
    notifyListeners();
  }

  Future<void> markMessageAsRead(String messageId) async {
    final index = _inboxMessages.indexWhere((message) => message.id == messageId);
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

  @override
  void dispose() {
    if (_transferChannel != null) {
      _supabase.removeChannel(_transferChannel!);
    }
    super.dispose();
  }
}
