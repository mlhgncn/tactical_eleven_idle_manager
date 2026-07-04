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
import '../services/notification_service.dart';

class GameProvider extends ChangeNotifier {
  GameProvider({
    GameRepository? repository,
    MatchRepository? matchRepository,
    Future<void> Function(String title, String body)? notificationSender,
    bool enableRealtime = true,
  })  : _repository = repository ?? SupabaseRepository(),
        _matchRepository = matchRepository ?? MatchRepository(),
        _notificationSender = notificationSender,
        _enableRealtime = enableRealtime {
    if (_enableRealtime) {
      _initRealtimeStreams();
    }
  }

  final GameRepository _repository;
  final MatchRepository _matchRepository;
  final Future<void> Function(String title, String body)? _notificationSender;
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

  /// Ekonomi hesaplaması: maç sonucu için gelir/gider öngörüsü
  Map<String, int> calculateMatchEconomy({required bool isWin}) {
    if (_activeClub == null) return {};
    
    // 1. Stadyum Geliri: (Kapasitesi * Bilet Fiyatı * 30% doluluk)
    final stadiumRevenue = (_activeClub!.stadiumCapacity * _activeClub!.ticketPrice) ~/ 3;
    
    // 2. Sponsor Geliri: Sponsor seviyesi * 500 GP
    final sponsorRevenue = _activeClub!.sponsorLevel * 500;
    
    // 3. Maç Bonusu: Kazanma = +300, Beraberlik = +100, Yenilgi = -200
    int matchBonus = isWin ? 300 : -200;
    
    // 4. Oyuncu Maliyeti: Her oyuncu ability * 2 GP per maç
    int playerWages = 0;
    for (final player in _squadPlayers) {
      playerWages += (player.currentAbility * 2).toInt();
    }
    
    // 5. Bakım Masrafı: Stadyum kapasitesi/200 + Tesis seviyesi*25
    final maintenanceCost = (_activeClub!.stadiumCapacity ~/ 200) + (_activeClub!.trainingFacilityLevel * 25);
    
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

  Future<List<ClubInfo>> loadAvailableClubs() async {
    return _repository.loadAvailableClubs();
  }

  Future<void> createClub(String name) async {
    final club = await _repository.createClub(name);
    if (club != null) {
      _activeClub = club;
      await refreshGameState();
    }
  }

  Future<void> claimClub(String clubId) async {
    final club = await _repository.claimClub(clubId);
    if (club != null) {
      _activeClub = club;
      await refreshGameState();
    }
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

  Future<MatchResult> playNextFixture() async {
    if (_activeClub == null) throw Exception('Aktif kulüp bulunamadı.');
    if (_fixtures.isEmpty) throw Exception('Oynanacak maç bulunmuyor.');

    final fixture = _fixtures.removeAt(0);
    final homeTactics = _tactics ?? Tactics(
      clubId: _activeClub!.id,
      captainId: _squadPlayers.isNotEmpty ? _squadPlayers.first.id : '',
      penaltyTakerId: _squadPlayers.isNotEmpty ? _squadPlayers.first.id : '',
    );
    final awaySquad = _generateOpponentSquad();
    final awayTactics = Tactics(
      clubId: 'away',
      captainId: awaySquad.isNotEmpty ? awaySquad.first.id : '',
      penaltyTakerId: awaySquad.isNotEmpty ? awaySquad.first.id : '',
    );

    final result = await simulateMatch(
      homeTeamName: _activeClub!.name,
      awayTeamName: fixture.opponentName,
      homeSquad: _squadPlayers,
      awaySquad: awaySquad,
      homeTactics: homeTactics,
      awayTactics: awayTactics,
    );

    _results.insert(0, result);
    
    // === EKONOMI HESAPLAMASI ===
    final economy = calculateMatchEconomy(isWin: result.homeScore > result.awayScore);
    final netIncome = economy['netIncome'] ?? 0;
    
    _activeClub = _activeClub!.copyWith(
      budget: _activeClub!.budget + netIncome,
      lastMaintenanceDate: DateTime.now(),
    );
    
    _inboxMessages.insert(
      0,
      InboxMessage(
        id: 'match-result-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Maç Sonucu',
        body: 'Sonuç: ${result.homeScore} - ${result.awayScore}.\n'
              'GELİR: Stadyum +${economy['stadiumRevenue']} | Sponsor +${economy['sponsorRevenue']} | Maç ${economy['matchBonus']}\n'
              'GİDER: Oyuncu -${economy['playerWages']} | Bakım -${economy['maintenanceCost']}\n'
              'Net: ${netIncome > 0 ? '+' : ''}$netIncome GP',
        isRead: false,
        createdAt: DateTime.now(),
      ),
    );

    notifyListeners();
    await (_notificationSender?.call(
          'Maç Sonucu',
          '${_activeClub!.name} ${result.homeScore} - ${result.awayScore} ${fixture.opponentName}',
        ) ??
        NotificationService.instance.sendNotification(
          'Maç Sonucu',
          '${_activeClub!.name} ${result.homeScore} - ${result.awayScore} ${fixture.opponentName}',
        ));
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
      // === MAX SEVİYE KONTROLÜ ===
      if (trainingFacilityLevel != null && trainingFacilityLevel > 10) {
        throw Exception('Tesis maksimum seviye 10 olabilir.');
      }
      if (stadiumCapacity != null && stadiumCapacity > 100000) {
        throw Exception('Stadyum maksimum kapasitesi 100.000 kişi olabilir.');
      }
      
      // === UPGRADE MALİYET HESAPLAMASI ===
      // Stadyum: 1000 + (yeni kapasitesi / 1000) GP
      // Tesis: 2000 + (seviye * 1500) GP  
      // Bilet Fiyatı: 500 GP (sabit)
      
      int totalCost = 0;
      
      if (stadiumCapacity != null && stadiumCapacity > _activeClub!.stadiumCapacity) {
        totalCost += 1000 + (stadiumCapacity ~/ 1000);
      }
      
      if (trainingFacilityLevel != null && trainingFacilityLevel > _activeClub!.trainingFacilityLevel) {
        totalCost += 2000 + (trainingFacilityLevel * 1500);
      }
      
      if (ticketPrice != null && ticketPrice > _activeClub!.ticketPrice) {
        totalCost += 500;
      }

      final newBudget = _activeClub!.budget - totalCost;
      if (newBudget < 0) throw Exception('Yeterli bütçe yok. Gerekli: $totalCost GP');

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
      
      // Bildirim ekle
      _inboxMessages.insert(
        0,
        InboxMessage(
          id: 'upgrade-${DateTime.now().millisecondsSinceEpoch}',
          title: 'Tesis Yükseltmesi',
          body: 'Yükseltme tamamlandı! Harcama: -$totalCost GP',
          isRead: false,
          createdAt: DateTime.now(),
        ),
      );

      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }
  
  /// Sponsor seviyesini yükselt (1-5 arası)
  Future<void> upgradeSponsor() async {
    if (_activeClub == null) throw Exception('Aktif kulüp bulunamadı.');
    if (_activeClub!.sponsorLevel >= 5) {
      throw Exception('Sponsor maksimum seviyesi 5 olabilir.');
    }
    if (_isBusy) return;

    _setBusy(true);
    try {
      // Sponsor yükseltme maliyeti: 5000 * sponsor seviyesi
      final cost = 5000 * _activeClub!.sponsorLevel;
      final newBudget = _activeClub!.budget - cost;
      
      if (newBudget < 0) throw Exception('Yeterli bütçe yok. Gerekli: $cost GP');

      _activeClub = _activeClub!.copyWith(
        budget: newBudget,
        sponsorLevel: _activeClub!.sponsorLevel + 1,
      );
      
      _inboxMessages.insert(
        0,
        InboxMessage(
          id: 'sponsor-${DateTime.now().millisecondsSinceEpoch}',
          title: 'Sponsor Anlaşması',
          body: 'Sponsor seviyesi ${_activeClub!.sponsorLevel}\'ye yükseltildi! Yeni aylık gelir: ${_activeClub!.sponsorLevel * 1000} GP',
          isRead: false,
          createdAt: DateTime.now(),
        ),
      );

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
