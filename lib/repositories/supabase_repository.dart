import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/errors.dart';
import '../services/error_reporting_service.dart';

import '../models/club_info.dart';
import '../models/inbox_message.dart';
import '../models/match_result.dart';
import '../models/player_fm.dart';
import '../models/profile.dart';
import '../models/transfer_market_item.dart';
import '../models/transfer_offer.dart';
import '../models/transfer_history_entry.dart';
import '../models/financial_transaction.dart';
import '../models/tactics.dart';
import '../models/player_pack.dart';
import '../models/diamond_product.dart';
import 'repository_interface.dart';

class SupabaseRepository implements GameRepository {
  SupabaseRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<T> _wrap<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on PostgrestException catch (e, st) {
      final msg = normalizeSupabaseMessage(e.message);
      final appEx = AppException.supabase(msg);
      // Treat DB errors as critical for reporting
      ErrorReportingService.report(appEx, st, reason: 'Supabase/PostgrestException');
      throw appEx;
    } on SocketException catch (e, st) {
      final appEx = AppException.network('Ağ bağlantısı bulunamadı. Lütfen internet bağlantınızı kontrol edin.');
      ErrorReportingService.report(appEx, st, reason: 'Network');
      throw appEx;
    } catch (e, st) {
      final appEx = AppException.unexpected(e.toString());
      ErrorReportingService.report(appEx, st, reason: 'Unexpected');
      throw appEx;
    }
  }

  Future<ClubInfo?> loadActiveClub() async {
    return _wrap(() async {
      final userId = currentUserId;
      if (userId == null) return null;

      final response = await _client
          .from('clubs')
          .select(
              'id,name,budget,blocked_budget,stadium_capacity,ticket_price,ticket_price_level,training_facility_level,sponsor_level,last_maintenance_date,sponsor_upgrade_completes_at,development_upgrade_type,development_target_value,development_completes_at,development_ad_uses')
          .eq('user_id', userId)
          .order('created_at', ascending: true)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return ClubInfo.fromMap(response as Map<String, dynamic>);
    });
  }

  Future<ClubInfo?> createLeagueAndJoin() async {
    return _wrap(() async {
      final response = await _client.rpc('create_league_and_join').single();

      if (response == null) return null;
      return ClubInfo.fromMap(response as Map<String, dynamic>);
    });
  }

  Future<ClubInfo?> joinLeagueWithCode(String invitationCode) async {
    return _wrap(() async {
      final response = await _client.rpc('join_league_with_code', params: {
        'p_invitation_code': invitationCode,
      }).single();

      if (response == null) return null;
      return ClubInfo.fromMap(response as Map<String, dynamic>);
    });
  }

  @override
  Future<void> leaveCurrentClub() async {
    return _wrap(() async {
      await _client.rpc('leave_current_club');
    });
  }

  Future<Profile?> loadProfile() async {
    return _wrap(() async {
      final userId = currentUserId;
      if (userId == null) return null;

      final response = await _client
          .from('profiles')
          .select(
              'id,full_name,avatar_url,email,language,fcm_token,username,league_titles,diamonds,created_at,updated_at')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return Profile.fromMap(response as Map<String, dynamic>);
    });
  }

  Future<Profile?> updateUsername(String username) async {
    return _wrap(() async {
      final userId = currentUserId;
      if (userId == null) return null;

      final response = await _client
          .from('profiles')
          .update({'username': username})
          .eq('id', userId)
          .select(
              'id,full_name,avatar_url,email,language,fcm_token,username,league_titles,diamonds,created_at,updated_at')
          .single();

      return Profile.fromMap(response as Map<String, dynamic>);
    });
  }

  Future<Profile?> upsertProfile(Profile profile) async {
    return _wrap(() async {
      final response = await _client
          .from('profiles')
          .upsert(profile.toMap())
          .select()
          .single();

      if (response == null) return null;
      return Profile.fromMap(response as Map<String, dynamic>);
    });
  }

  Future<PlayerFM?> startPlayerDevelopment({required String playerId}) async {
    return _wrap(() async {
      final response = await _client.rpc('start_player_development', params: {
        'p_player_id': playerId,
      }).select(
        'id,club_id,name,position,age,current_ability,potential_ability,morale,fitness,finishing,passing,tackling,composure,determination,consistency,injury_proneness,form_rating,injury_type,injury_duration_weeks,is_suspended,development_completes_at,development_ad_uses',
      ).single();

      if (response == null) return null;
      return PlayerFM.fromMap(response as Map<String, dynamic>);
    });
  }

  Future<PlayerFM?> reducePlayerDevelopmentTimeWithAd({required String playerId}) async {
    return _wrap(() async {
      final response = await _client.rpc('reduce_player_development_time_with_ad', params: {
        'p_player_id': playerId,
      }).select(
        'id,club_id,name,position,age,current_ability,potential_ability,morale,fitness,finishing,passing,tackling,composure,determination,consistency,injury_proneness,form_rating,injury_type,injury_duration_weeks,is_suspended,development_completes_at,development_ad_uses',
      ).single();

      if (response == null) return null;
      return PlayerFM.fromMap(response as Map<String, dynamic>);
    });
  }

  Future<ClubInfo?> reduceClubDevelopmentTimeWithAd({required String clubId}) async {
    return _wrap(() async {
      final response = await _client.rpc('reduce_club_development_time_with_ad', params: {
        'p_club_id': clubId,
      }).single();

      if (response == null) return null;
      return ClubInfo.fromMap(response as Map<String, dynamic>);
    });
  }

  Future<List<PlayerFM>> loadSquadPlayers(String clubId) async {
    return _wrap(() async {
      // Whole roster (30-34 players), not just a starting XI - callers that
      // need the starting XI derive it client-side (squad_screen takes the
      // top 11 by ability). A hardcoded .limit(11) here used to mean the app
      // could never show more than 11 players even after rosters were
      // expanded to a full squad.
      final data = await _client
          .from('players')
          .select(
              'id,club_id,name,position,age,current_ability,potential_ability,morale,fitness,finishing,passing,tackling,composure,determination,consistency,injury_proneness,injury_type,injury_duration_weeks,is_suspended,development_completes_at,development_ad_uses')
          .eq('club_id', clubId)
          .order('current_ability', ascending: false);

      if (data is! List) return <PlayerFM>[];
      return data.cast<Map<String, dynamic>>().map(PlayerFM.fromMap).toList();
    });
  }

  Future<List<InboxMessage>> loadInboxMessages() async {
    return _wrap(() async {
      final userId = currentUserId;
      if (userId == null) return <InboxMessage>[];

      final data = await _client
          .from('inbox_messages')
          .select('id,title,body,is_read,created_at')
          .eq('recipient_id', userId)
          .order('created_at', ascending: false);

      if (data is! List<dynamic>) return <InboxMessage>[];

      return data.cast<Map<String, dynamic>>().map(InboxMessage.fromMap).toList();
    });
  }

  Future<InboxMessage?> addInboxMessage({required String title, required String body}) async {
    return _wrap(() async {
      final userId = currentUserId;
      if (userId == null) return null;

      final response = await _client
          .from('inbox_messages')
          .insert({
            'recipient_id': userId,
            'title': title,
            'body': body,
            'is_read': false,
          })
          .select('id,title,body,is_read,created_at')
          .single();

      if (response == null) return null;
      return InboxMessage.fromMap(response as Map<String, dynamic>);
    });
  }

  Future<Map<String, dynamic>?> awardAdReward({required String rewardType, int? amount}) async {
    return _wrap(() async {
      final response = await _client.rpc('award_ad_reward', params: {
        'p_reward_type': rewardType,
        'p_amount': amount,
      }).single();

      if (response == null) return null;
      if (response is Map<String, dynamic>) return response;
      return Map<String, dynamic>.from(response as Map);
    });
  }

  Future<List<TransferMarketItem>> loadTransferMarket() async {
    return _wrap(() async {
      final data = await _client
          .from('transfer_market')
          .select('id,player_id,asking_price,players(name,position,age,current_ability,club:clubs(id,name))');

      if (data is! List<dynamic>) {
        return <TransferMarketItem>[];
      }

      return data
          .cast<Map<String, dynamic>>()
          .map(TransferMarketItem.fromMap)
          .toList();
    });
  }

  Future<List<PlayerFM>> loadFreeAgents() async {
    return _wrap(() async {
      final data = await _client
          .from('players')
          .select(
              'id,club_id,name,position,age,current_ability,potential_ability,morale,fitness,finishing,passing,tackling,composure,determination,consistency,injury_proneness,injury_type,injury_duration_weeks,is_suspended')
          .filter('club_id', 'is', null)
          .order('current_ability', ascending: false);

      if (data is! List<dynamic>) return <PlayerFM>[];
      return data.cast<Map<String, dynamic>>().map(PlayerFM.fromMap).toList();
    });
  }

  Future<ClubInfo?> signFreeAgent({required String playerId}) async {
    return _wrap(() async {
      final updated = await _client.rpc('sign_free_agent', params: {
        'p_player_id': playerId,
      }).single();

      if (updated == null) return null;
      return ClubInfo.fromMap(updated as Map<String, dynamic>);
    });
  }

  Future<List<PlayerPack>> loadPlayerPacks() async {
    return _wrap(() async {
      final data = await _client
          .from('player_packs')
          .select('id,name,diamond_cost,guaranteed_min_ability,random_min_ability,random_max_ability,random_slot_count')
          .order('sort_order', ascending: true);

      if (data is! List<dynamic>) return <PlayerPack>[];
      return data.cast<Map<String, dynamic>>().map(PlayerPack.fromMap).toList();
    });
  }

  Future<List<PlayerFM>> openPlayerPack({required String packId}) async {
    return _wrap(() async {
      final data = await _client.rpc('open_player_pack', params: {'p_pack_id': packId});
      if (data is! List<dynamic>) return <PlayerFM>[];
      return data.cast<Map<String, dynamic>>().map(PlayerFM.fromMap).toList();
    });
  }

  Future<List<DiamondProduct>> loadDiamondProducts() async {
    return _wrap(() async {
      final data = await _client
          .from('diamond_products')
          .select('product_id,diamonds,label,bonus_note')
          .order('sort_order', ascending: true);

      if (data is! List<dynamic>) return <DiamondProduct>[];
      return data.cast<Map<String, dynamic>>().map(DiamondProduct.fromMap).toList();
    });
  }

  Future<Map<String, dynamic>> verifyIapPurchase({
    required String receiptData,
    required String productId,
    required String transactionId,
  }) async {
    return _wrap(() async {
      final response = await _client.functions.invoke('verify_iap_purchase', body: {
        'receiptData': receiptData,
        'productId': productId,
        'transactionId': transactionId,
      });

      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data['error'] != null) {
          throw AppException(data['error'].toString());
        }
        return data;
      }
      throw AppException('Satın alma doğrulanamadı.');
    });
  }

  Future<TransferOffer?> makeTransferOffer({required String playerId, required int offerAmount}) async {
    return _wrap(() async {
      final created = await _client.rpc('make_transfer_offer', params: {
        'p_player_id': playerId,
        'p_offer_amount': offerAmount,
      }).select('id,player_id,from_club_id,to_club_id,offer_amount,status,created_at,responded_at,player:players(name),from_club:clubs!from_club_id(name),to_club:clubs!to_club_id(name)').single();

      if (created == null) return null;
      return TransferOffer.fromMap(created as Map<String, dynamic>);
    });
  }

  Future<void> respondToTransferOffer({required String offerId, required bool accept}) async {
    return _wrap(() async {
      await _client.rpc('respond_to_transfer_offer', params: {
        'p_offer_id': offerId,
        'p_accept': accept,
      });
    });
  }

  Future<void> withdrawTransferOffer({required String offerId}) async {
    return _wrap(() async {
      await _client.rpc('withdraw_transfer_offer', params: {
        'p_offer_id': offerId,
      });
    });
  }

  Future<List<TransferOffer>> loadIncomingTransferOffers(String clubId) async {
    return _wrap(() async {
      final data = await _client
          .from('transfer_offers')
          .select('id,player_id,from_club_id,to_club_id,offer_amount,status,created_at,responded_at,player:players(name),from_club:clubs!from_club_id(name),to_club:clubs!to_club_id(name)')
          .eq('to_club_id', clubId)
          .order('created_at', ascending: false);

      if (data is! List<dynamic>) return <TransferOffer>[];
      return data.cast<Map<String, dynamic>>().map(TransferOffer.fromMap).toList();
    });
  }

  Future<List<TransferOffer>> loadOutgoingTransferOffers(String clubId) async {
    return _wrap(() async {
      final data = await _client
          .from('transfer_offers')
          .select('id,player_id,from_club_id,to_club_id,offer_amount,status,created_at,responded_at,player:players(name),from_club:clubs!from_club_id(name),to_club:clubs!to_club_id(name)')
          .eq('from_club_id', clubId)
          .order('created_at', ascending: false);

      if (data is! List<dynamic>) return <TransferOffer>[];
      return data.cast<Map<String, dynamic>>().map(TransferOffer.fromMap).toList();
    });
  }

  /// club_id -> username for every club in [clubIds] that's owned by a real
  /// user with a username set. profiles' RLS only lets a user read their own
  /// row, so a plain embedded select (clubs -> profiles) would return null
  /// for everyone else's club; this SECURITY DEFINER RPC is the narrow,
  /// safe way to resolve just the public username for a set of clubs.
  Future<Map<String, String>> _clubOwnerUsernames(Iterable<String> clubIds) async {
    final ids = clubIds.toSet().toList();
    if (ids.isEmpty) return const {};
    final data = await _client.rpc('get_club_owner_usernames', params: {'p_club_ids': ids});
    if (data is! List<dynamic>) return const {};
    return {
      for (final row in data.cast<Map<String, dynamic>>())
        if (row['username'] != null) row['club_id'] as String: row['username'] as String,
    };
  }

  Future<List<Map<String, dynamic>>> loadFixturesForClub(String clubId) async {
    return _wrap(() async {
      final data = await _client
          .from('matches')
          .select(
              'id,match_date,is_played,home_score,away_score,home_club_id,away_club_id,home_club:clubs!home_club_id(name),away_club:clubs!away_club_id(name),week,league_id,season_id')
          .or('home_club_id.eq.$clubId,away_club_id.eq.$clubId')
          .order('match_date', ascending: true);

      if (data is! List<dynamic>) return <Map<String, dynamic>>[];
      final fixtures = data.cast<Map<String, dynamic>>();

      final usernames = await _clubOwnerUsernames(fixtures.expand(
        (f) => [f['home_club_id'] as String, f['away_club_id'] as String],
      ));
      if (usernames.isNotEmpty) {
        for (final f in fixtures) {
          final homeClub = f['home_club'] as Map<String, dynamic>?;
          if (homeClub != null) homeClub['username'] = usernames[f['home_club_id']];
          final awayClub = f['away_club'] as Map<String, dynamic>?;
          if (awayClub != null) awayClub['username'] = usernames[f['away_club_id']];
        }
      }

      return fixtures;
    });
  }

  Future<List<Map<String, dynamic>>> loadMatchEvents(String matchId) async {
    return _wrap(() async {
      final data = await _client
          .from('match_events')
          .select('id,minute,event_type,club_id,player_id,assist_player_id,description')
          .eq('match_id', matchId)
          .order('minute', ascending: true);

      if (data is! List<dynamic>) return <Map<String, dynamic>>[];
      return data.cast<Map<String, dynamic>>();
    });
  }

  Future<void> _attachOwnerUsernames(List<Map<String, dynamic>> standingsRows) async {
    final clubIds = standingsRows
        .map((row) => (row['club'] as Map?)?['id'] as String?)
        .whereType<String>();
    final usernames = await _clubOwnerUsernames(clubIds);
    if (usernames.isEmpty) return;
    for (final row in standingsRows) {
      final club = row['club'] as Map<String, dynamic>?;
      if (club != null) club['username'] = usernames[club['id']];
    }
  }

  Future<Map<String, dynamic>?> loadCurrentSeasonState(String clubId) async {
    return _wrap(() async {
      final club = await _client
          .from('clubs')
          .select('league_id')
          .eq('id', clubId)
          .maybeSingle();

      final leagueId = club?['league_id'] as String?;
      if (leagueId == null) return null;

      final response = await _client
          .from('seasons')
          .select(
              'id,name,current_week,is_active,is_completed,league:leagues(id,name,invitation_code),champion_club:clubs(id,name)')
          .eq('league_id', leagueId)
          .eq('is_active', true)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      final season = Map<String, dynamic>.from(response as Map<String, dynamic>);
      final standingsResponse = await _client
          .from('league_standings')
          .select(
              'position,points,played,wins,draws,losses,goals_for,goals_against,goal_difference,club:clubs(id,name)')
          .eq('season_id', season['id'])
          .order('points', ascending: false)
          .order('goal_difference', ascending: false)
          .order('goals_for', ascending: false);

      if (standingsResponse is List<dynamic>) {
        final rows = standingsResponse.cast<Map<String, dynamic>>();
        await _attachOwnerUsernames(rows);
        season['standings'] = rows;
      }

      return season;
    });
  }

  Future<List<Map<String, dynamic>>> loadLeagueStandings(
      String seasonId) async {
    return _wrap(() async {
      final data = await _client
          .from('league_standings')
          .select(
              'position,points,played,wins,draws,losses,goals_for,goals_against,goal_difference,club:clubs(id,name)')
          .eq('season_id', seasonId)
          .order('points', ascending: false)
          .order('goal_difference', ascending: false)
          .order('goals_for', ascending: false);

      if (data is! List<dynamic>) return <Map<String, dynamic>>[];
      final rows = data.cast<Map<String, dynamic>>();
      await _attachOwnerUsernames(rows);
      return rows;
    });
  }

  Future<TransferMarketItem?> listPlayerForTransfer({required String playerId, required int askingPrice}) async {
    return _wrap(() async {
      final created = await _client.rpc('list_player_for_transfer', params: {
        'p_player_id': playerId,
        'p_asking_price': askingPrice,
      }).single();

      if (created == null) return null;
      return TransferMarketItem.fromMap(created as Map<String, dynamic>);
    });
  }

  Future<void> withdrawTransferListing({required String playerId}) async {
    return _wrap(() async {
      await _client.rpc('withdraw_transfer_listing', params: {
        'p_player_id': playerId,
      });
    });
  }

  Future<List<TransferHistoryEntry>> loadTransferHistory(String clubId) async {
    return _wrap(() async {
      final rows = await _client
          .from('transfer_history')
          .select('id,player_id,seller_club_id,buyer_club_id,price,completed_at')
          .or('seller_club_id.eq.$clubId,buyer_club_id.eq.$clubId')
          .order('completed_at', ascending: false);

      if (rows is! List || rows.isEmpty) return <TransferHistoryEntry>[];
      final typedRows = rows.cast<Map<String, dynamic>>();

      final playerIds = typedRows.map((r) => r['player_id'] as String).toSet().toList();
      final clubIds = typedRows
          .expand((r) => [r['seller_club_id'] as String?, r['buyer_club_id'] as String?])
          .whereType<String>()
          .toSet()
          .toList();

      final playerRows = playerIds.isEmpty
          ? <Map<String, dynamic>>[]
          : (await _client.from('players').select('id,name').inFilter('id', playerIds))
              .cast<Map<String, dynamic>>();
      final clubRows = clubIds.isEmpty
          ? <Map<String, dynamic>>[]
          : (await _client.from('clubs').select('id,name').inFilter('id', clubIds))
              .cast<Map<String, dynamic>>();

      final playerNames = {for (final p in playerRows) p['id'] as String: p['name'] as String? ?? 'Bilinmiyor'};
      final clubNames = {for (final c in clubRows) c['id'] as String: c['name'] as String? ?? 'Bilinmiyor'};

      return typedRows.map((row) {
        final sellerId = row['seller_club_id'] as String?;
        final buyerId = row['buyer_club_id'] as String?;
        return TransferHistoryEntry(
          id: row['id'] as String,
          playerId: row['player_id'] as String,
          playerName: playerNames[row['player_id']] ?? 'Bilinmiyor',
          sellerClubId: sellerId,
          sellerClubName: sellerId != null ? (clubNames[sellerId] ?? 'Bilinmiyor') : 'Bilinmiyor',
          buyerClubId: buyerId,
          buyerClubName: buyerId != null ? (clubNames[buyerId] ?? 'Bilinmiyor') : 'Bilinmiyor',
          price: (row['price'] as num).toInt(),
          completedAt: DateTime.parse(row['completed_at'] as String),
        );
      }).toList();
    });
  }

  @override
  Future<bool> markMessageAsRead(String messageId) async {
    return _wrap(() async {
      final userId = currentUserId;
      if (userId == null) return false;

      final response = await _client
          .from('inbox_messages')
          .update({'is_read': true})
          .eq('id', messageId)
          .eq('recipient_id', userId)
          .select()
          .single();

      return response != null;
    });
  }

  @override
  Future<ClubInfo?> startClubDevelopment({
    required String clubId,
    required String upgradeType,
    required int targetValue,
  }) async {
    return _wrap(() async {
      final updated = await _client.rpc('start_club_development', params: {
        'p_club_id': clubId,
        'p_upgrade_type': upgradeType,
        'p_target_value': targetValue,
      }).single();

      if (updated == null) return null;
      return ClubInfo.fromMap(updated as Map<String, dynamic>);
    });
  }

  @override
  Future<ClubInfo?> upgradeSponsor({required String clubId}) async {
    return _wrap(() async {
      final updated = await _client.rpc('upgrade_sponsor', params: {
        'club_id': clubId,
      }).single();

      if (updated == null) return null;
      return ClubInfo.fromMap(updated as Map<String, dynamic>);
    });
  }

  @override
  Future<List<FinancialTransaction>> loadFinancialTransactions(String clubId) async {
    return _wrap(() async {
      final data = await _client
        .from('financial_transactions')
        .select('id,club_id,type,amount,description,source,created_at')
        .eq('club_id', clubId)
        .order('created_at', ascending: false)
        .limit(50);

      if (data is! List<dynamic>) return <FinancialTransaction>[];

      return data
        .cast<Map<String, dynamic>>()
        .map(FinancialTransaction.fromMap)
        .toList();
    });
  }

  Future<Tactics?> loadTacticsForClub(String clubId) {
    return loadTactics(clubId);
  }

  @override
  Future<bool> isAdmin() async {
    return _wrap(() async {
      final dynamic resp = await _client.rpc('is_admin').single();
      if (resp == null) return false;
      if (resp is bool) return resp;
      if (resp is String) return resp == 't' || resp.toLowerCase() == 'true';
      if (resp is num) return resp == 1;
      if (resp is Map) {
        final first = resp.values.isNotEmpty ? resp.values.first : null;
        if (first is bool) return first;
        if (first is String) return first == 't' || first.toLowerCase() == 'true';
        if (first is num) return first == 1;
      }
      return false;
    });
  }

  Future<List<Map<String, dynamic>>> adminListUsers() async {
    return _wrap(() async {
      final data = await _client.rpc('admin_list_users').select();
      if (data is List<dynamic>) return data.cast<Map<String, dynamic>>();
      return <Map<String, dynamic>>[];
    });
  }

  Future<List<Map<String, dynamic>>> adminListClubs() async {
    return _wrap(() async {
      final data = await _client.rpc('admin_list_clubs').select();
      if (data is List<dynamic>) return data.cast<Map<String, dynamic>>();
      return <Map<String, dynamic>>[];
    });
  }

  Future<Map<String, dynamic>?> adminCreateGiftCode({required String code, required int amount, DateTime? expiresAt}) async {
    return _wrap(() async {
      final params = {
        'p_code': code,
        'p_amount': amount,
        'p_expires_at': expiresAt?.toIso8601String()
      };
      final created = await _client.rpc('admin_create_gift_code', params: params).single();
      if (created == null) return null;
      return Map<String, dynamic>.from(created as Map);
    });
  }

  Future<Map<String, dynamic>?> adminCreateEvent({required String title, required String body, DateTime? startsAt, DateTime? endsAt}) async {
    return _wrap(() async {
      final params = {
        'p_title': title,
        'p_body': body,
        'p_starts_at': startsAt?.toIso8601String(),
        'p_ends_at': endsAt?.toIso8601String()
      };
      final created = await _client.rpc('admin_create_event', params: params).single();
      if (created == null) return null;
      return Map<String, dynamic>.from(created as Map);
    });
  }

  Future<Map<String, dynamic>?> adminSendPush({required String title, required String body, String? targetUserId}) async {
    return _wrap(() async {
      final params = {
        'p_title': title,
        'p_body': body,
        'p_target_user_id': targetUserId
      };
      final created = await _client.rpc('admin_send_push', params: params).single();
      if (created == null) return null;
      return Map<String, dynamic>.from(created as Map);
    });
  }

  Future<Map<String, dynamic>?> adminUpdatePlayer({required String playerId, String? name, String? position, int? age, int? currentAbility, int? potentialAbility}) async {
    return _wrap(() async {
      final params = {
        'p_player_id': playerId,
        'p_name': name,
        'p_position': position,
        'p_age': age,
        'p_current_ability': currentAbility,
        'p_potential_ability': potentialAbility,
      };
      final updated = await _client.rpc('admin_update_player', params: params).single();
      if (updated == null) return null;
      return Map<String, dynamic>.from(updated as Map);
    });
  }

  Future<Tactics?> loadTactics(String clubId) async {
    return _wrap(() async {
      final data = await _client
          .from('tactics')
          .select(
              'club_id,formation,mentality,captain_id,penalty_taker_id,free_kick_taker_id,corner_taker_id,press_intensity,tempo,defensive_line,offside_trap,time_wasting,starting_eleven_ids')
          .eq('club_id', clubId)
          .maybeSingle();

      if (data == null) return null;
      return Tactics.fromMap(data as Map<String, dynamic>);
    });
  }

  Future<Tactics?> saveTacticsForClub(String clubId, Tactics tactics) {
    return saveTactics(clubId, tactics);
  }

  Future<Tactics?> saveTactics(String clubId, Tactics tactics) async {
    return _wrap(() async {
      final payload = tactics.toMap();
      payload['club_id'] = clubId;
      final data =
          await _client.from('tactics').upsert(payload).select().maybeSingle();

      if (data == null) return null;
      return Tactics.fromMap(data as Map<String, dynamic>);
    });
  }

  Future<void> updateFcmToken(String token) async {
    return _wrap(() async {
      final userId = currentUserId;
      if (userId == null) return;

      await _client.from('profiles').upsert({
        'id': userId,
        'fcm_token': token,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    });
  }

  Future<void> updateNotificationPreference(bool enabled) async {
    return _wrap(() async {
      final userId = currentUserId;
      if (userId == null) return;

      await _client.from('profiles').upsert({
        'id': userId,
        'notifications_enabled': enabled,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    });
  }

  Future<bool?> loadNotificationPreference() async {
    return _wrap(() async {
      final userId = currentUserId;
      if (userId == null) return null;

      final resp = await _client.from('profiles').select('notifications_enabled').eq('id', userId).maybeSingle();
      if (resp == null) return null;
      final map = resp as Map<String, dynamic>;
      return map['notifications_enabled'] as bool?;
    });
  }

  @override
  Future<MatchResult?> playNextFixture() async {
    return _wrap(() async {
      final response = await _client.functions.invoke('play_next_fixture', body: {});
      if (response.status != 200) {
        throw Exception('Maç oynatma işlemi başarısız oldu.');
      }

      final data = response.data;
      if (data == null) {
        return null;
      }

      final resultData = Map<String, dynamic>.from(data as Map<String, dynamic>);
      final result = resultData['result'];
      if (result == null) {
        return null;
      }

      return MatchResult.fromMap(Map<String, dynamic>.from(result as Map<String, dynamic>));
    });
  }
}
