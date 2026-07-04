import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/player_fm.dart';
import '../models/transfer_market_item.dart';

class ClubInfo {
  final String id;
  final int budget;
  final int stadiumCapacity;
  final int ticketPrice;
  final int trainingFacilityLevel;

  const ClubInfo({
    required this.id,
    required this.budget,
    required this.stadiumCapacity,
    required this.ticketPrice,
    required this.trainingFacilityLevel,
  });

  ClubInfo copyWith({
    int? budget,
    int? stadiumCapacity,
    int? ticketPrice,
    int? trainingFacilityLevel,
  }) {
    return ClubInfo(
      id: id,
      budget: budget ?? this.budget,
      stadiumCapacity: stadiumCapacity ?? this.stadiumCapacity,
      ticketPrice: ticketPrice ?? this.ticketPrice,
      trainingFacilityLevel: trainingFacilityLevel ?? this.trainingFacilityLevel,
    );
  }
}

class InboxMessage {
  final String id;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  const InboxMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory InboxMessage.fromMap(Map<String, dynamic> map) {
    return InboxMessage(
      id: map['id'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      isRead: map['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class GameProvider extends ChangeNotifier {
  GameProvider({SupabaseClient? supabase}) : _supabase = supabase ?? Supabase.instance.client {
    _initRealtimeStreams();
  }

  final SupabaseClient _supabase;
  RealtimeChannel? _transferChannel;

  ClubInfo? _activeClub;
  List<PlayerFM> _squadPlayers = <PlayerFM>[];
  List<InboxMessage> _inboxMessages = <InboxMessage>[];
  List<TransferMarketItem> _transferMarketItems = <TransferMarketItem>[];
  bool _isLoading = false;
  bool _isBusy = false;
  bool _isSyncing = false;

  ClubInfo? get activeClub => _activeClub;
  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;
  bool get isSyncing => _isSyncing;
  List<PlayerFM> get squadPlayers => List.unmodifiable(_squadPlayers);
  List<InboxMessage> get inboxMessages => List.unmodifiable(_inboxMessages);
  List<TransferMarketItem> get transferMarketItems => List.unmodifiable(_transferMarketItems);

  Future<void> refreshGameState() async {
    _setLoading(true);
    try {
      await _loadActiveClub();
      await Future.wait(<Future<void>>[
        _loadSquadPlayers(),
        _loadInboxMessages(),
        _loadTransferMarket(),
      ]);
    } catch (error) {
      debugPrint('GameProvider refresh failed: $error');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadActiveClub() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      _activeClub = null;
      return;
    }

    final response = await _supabase
        .from('clubs')
        .select('id,budget,stadium_capacity,ticket_price,training_facility_level')
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) {
      _activeClub = null;
      return;
    }

    _activeClub = ClubInfo(
      id: response['id'] as String,
      budget: (response['budget'] as num).toInt(),
      stadiumCapacity: (response['stadium_capacity'] as num).toInt(),
      ticketPrice: (response['ticket_price'] as num).toInt(),
      trainingFacilityLevel: (response['training_facility_level'] as num).toInt(),
    );
  }

  Future<void> _loadSquadPlayers() async {
    if (_activeClub == null) {
      _squadPlayers = <PlayerFM>[];
      return;
    }

    final data = await _supabase
        .from('players')
        .select('id,club_id,name,position,age,current_ability,potential_ability,morale,fitness,finishing,passing,tackling,composure,determination,consistency,injury_proneness')
        .eq('club_id', _activeClub!.id)
        .order('name', ascending: true);

    _squadPlayers = (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((raw) => PlayerFM(
              id: raw['id'] as String,
              clubId: raw['club_id'] as String,
              name: raw['name'] as String,
              position: raw['position'] as String,
              age: (raw['age'] as num).toInt(),
              currentAbility: (raw['current_ability'] as num).toInt(),
              potentialAbility: (raw['potential_ability'] as num).toInt(),
              morale: (raw['morale'] as num).toInt(),
              fitness: (raw['fitness'] as num).toInt(),
              finishing: (raw['finishing'] as num).toInt(),
              passing: (raw['passing'] as num).toInt(),
              tackling: (raw['tackling'] as num).toInt(),
              composure: (raw['composure'] as num).toInt(),
              determination: (raw['determination'] as num).toInt(),
              consistency: (raw['consistency'] as num).toInt(),
              injuryProneness: (raw['injury_proneness'] as num).toInt(),
            ))
        .toList();
  }

  Future<void> _loadInboxMessages() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      _inboxMessages = <InboxMessage>[];
      return;
    }

    final data = await _supabase
        .from('inbox_messages')
        .select('id,title,body,is_read,created_at')
        .eq('recipient_id', userId)
        .order('created_at', ascending: false);

    _inboxMessages = (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(InboxMessage.fromMap)
        .toList();
  }

  Future<void> _loadTransferMarket() async {
    _setSyncing(true);
    try {
      final data = await _supabase
          .from('transfer_market')
          .select('id,player_id,current_highest_bid,highest_bidder_id,end_time')
          .order('end_time', ascending: true);

      _transferMarketItems = (data as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(TransferMarketItem.fromMap)
          .toList();
    } finally {
      _setSyncing(false);
    }
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
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Kullanıcı oturumu bulunamadı.');
    }

    if (_isBusy) return;

    _setBusy(true);
    try {
      final updated = await _supabase
          .from('transfer_market')
          .update({
            'current_highest_bid': bidAmount,
            'highest_bidder_id': userId,
          })
          .eq('id', marketId)
          .lt('current_highest_bid', bidAmount)
          .select()
          .single();

      _upsertTransferMarketItem(TransferMarketItem.fromMap(Map<String, dynamic>.from(updated as Map<String, dynamic>)));
      notifyListeners();
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

      await _supabase.from('clubs').update({'budget': newBudget}).eq('id', _activeClub!.id).select().single();
      await _supabase.from('players').update({'club_id': null}).eq('id', playerId);

      _activeClub = _activeClub!.copyWith(budget: newBudget);
      _squadPlayers.removeWhere((player) => player.id == playerId);
      notifyListeners();
      await refreshGameState();
    } finally {
      _setBusy(false);
    }
  }

  void markMessageAsRead(String messageId) {
    final index = _inboxMessages.indexWhere((message) => message.id == messageId);
    if (index < 0) return;

    final message = _inboxMessages[index];
    if (message.isRead) return;

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
