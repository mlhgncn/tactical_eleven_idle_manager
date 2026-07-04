import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/club_info.dart';
import '../models/inbox_message.dart';
import '../models/player_fm.dart';
import '../models/profile.dart';
import '../models/transfer_market_item.dart';
import 'repository_interface.dart';

class SupabaseRepository implements GameRepository {
  SupabaseRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<ClubInfo?> loadActiveClub() async {
    final userId = currentUserId;
    if (userId == null) return null;

    final response = await _client
        .from('clubs')
        .select('id,name,budget,stadium_capacity,ticket_price,training_facility_level')
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;
    return ClubInfo.fromMap(response as Map<String, dynamic>);
  }

  Future<List<ClubInfo>> loadAvailableClubs() async {
    final data = await _client
        .from('clubs')
        .select('id,name,budget,stadium_capacity,ticket_price,training_facility_level')
        .is_('user_id', null)
        .order('name', ascending: true);

    return (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(ClubInfo.fromMap)
        .toList();
  }

  Future<ClubInfo?> createClub(String name) async {
    final userId = currentUserId;
    if (userId == null) return null;

    final response = await _client
        .from('clubs')
        .insert({
          'name': name,
          'user_id': userId,
        })
        .select()
        .single();

    if (response == null) return null;
    return ClubInfo.fromMap(response as Map<String, dynamic>);
  }

  Future<ClubInfo?> claimClub(String clubId) async {
    final response = await _client.rpc('claim_club', params: {
      'club_id': clubId,
    }).single();

    if (response == null) return null;
    return ClubInfo.fromMap(response as Map<String, dynamic>);
  }

  Future<Profile?> loadProfile() async {
    final userId = currentUserId;
    if (userId == null) return null;

    final response = await _client
        .from('profiles')
        .select('id,full_name,avatar_url,email,language,fcm_token,created_at,updated_at')
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return null;
    return Profile.fromMap(response as Map<String, dynamic>);
  }

  Future<Profile?> upsertProfile(Profile profile) async {
    final response = await _client
        .from('profiles')
        .upsert(profile.toMap())
        .select()
        .single();

    if (response == null) return null;
    return Profile.fromMap(response as Map<String, dynamic>);
  }

  Future<List<PlayerFM>> loadSquadPlayers(String clubId) async {
    final data = await _client
        .from('players')
        .select('id,club_id,name,position,age,current_ability,potential_ability,morale,fitness,finishing,passing,tackling,composure,determination,consistency,injury_proneness')
        .eq('club_id', clubId)
        .order('name', ascending: true);

    return (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PlayerFM.fromMap)
        .toList();
  }

  Future<List<InboxMessage>> loadInboxMessages() async {
    final userId = currentUserId;
    if (userId == null) return <InboxMessage>[];

    final data = await _client
        .from('inbox_messages')
        .select('id,title,body,is_read,created_at')
        .eq('recipient_id', userId)
        .order('created_at', ascending: false);

    return (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(InboxMessage.fromMap)
        .toList();
  }

  Future<List<TransferMarketItem>> loadTransferMarket() async {
    final data = await _client
        .from('transfer_market')
        .select('id,player_id,current_highest_bid,highest_bidder_id,end_time,players(name,position)')
        .order('end_time', ascending: true);

    return (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(TransferMarketItem.fromMap)
        .toList();
  }

  Future<TransferMarketItem?> placeBid(String marketId, int bidAmount) async {
    final updated = await _client.rpc('place_transfer_bid', params: {
      'market_id': marketId,
      'bid_amount': bidAmount,
    }).single();

    if (updated == null) return null;
    return TransferMarketItem.fromMap(updated as Map<String, dynamic>);
  }

  Future<ClubInfo?> acceptTransferOffer({required String clubId, required int newBudget, required String playerId}) async {
    final clubResponse = await _client
        .from('clubs')
        .update({'budget': newBudget})
        .eq('id', clubId)
        .select()
        .single();

    await _client.from('players').update({'club_id': null}).eq('id', playerId);

    if (clubResponse == null) return null;
    return ClubInfo.fromMap(clubResponse as Map<String, dynamic>);
  }

  Future<bool> markMessageAsRead(String messageId) async {
    final response = await _client
        .from('inbox_messages')
        .update({'is_read': true})
        .eq('id', messageId)
        .select()
        .single();

    return response != null;
  }

  Future<ClubInfo?> upgradeClub({
    required String clubId,
    int? stadiumCapacity,
    int? trainingFacilityLevel,
    int? ticketPrice,
    required int budget,
  }) async {
    final updateFields = <String, dynamic>{'budget': budget};
    if (stadiumCapacity != null) updateFields['stadium_capacity'] = stadiumCapacity;
    if (trainingFacilityLevel != null) updateFields['training_facility_level'] = trainingFacilityLevel;
    if (ticketPrice != null) updateFields['ticket_price'] = ticketPrice;

    final response = await _client
        .from('clubs')
        .update(updateFields)
        .eq('id', clubId)
        .select()
        .single();

    if (response == null) return null;
    return ClubInfo.fromMap(response as Map<String, dynamic>);
  }

  Future<void> updateFcmToken(String token) async {
    final userId = currentUserId;
    if (userId == null) return;

    await _client.from('profiles').upsert({
      'id': userId,
      'fcm_token': token,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
