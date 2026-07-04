// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tactical_eleven_idle_manager/main.dart';
import 'package:tactical_eleven_idle_manager/models/club_info.dart';
import 'package:tactical_eleven_idle_manager/models/inbox_message.dart';
import 'package:tactical_eleven_idle_manager/models/profile.dart';
import 'package:tactical_eleven_idle_manager/models/player_fm.dart';
import 'package:tactical_eleven_idle_manager/models/transfer_market_item.dart';
import 'package:tactical_eleven_idle_manager/providers/game_provider.dart';
import 'package:tactical_eleven_idle_manager/repositories/repository_interface.dart';

class _TestGameRepository extends GameRepository {
  @override
  String? get currentUserId => null;

  @override
  Future<ClubInfo?> loadActiveClub() async => null;

  @override
  Future<Profile?> loadProfile() async => null;

  @override
  Future<List<PlayerFM>> loadSquadPlayers(String clubId) async => <PlayerFM>[];

  @override
  Future<List<InboxMessage>> loadInboxMessages() async => <InboxMessage>[];

  @override
  Future<List<TransferMarketItem>> loadTransferMarket() async => <TransferMarketItem>[];

  @override
  Future<TransferMarketItem?> placeBid(String marketId, int bidAmount) async => null;

  @override
  Future<ClubInfo?> acceptTransferOffer({required String clubId, required int newBudget, required String playerId}) async => null;

  @override
  Future<bool> markMessageAsRead(String messageId) async => false;

  @override
  Future<ClubInfo?> upgradeClub({required String clubId, int? stadiumCapacity, int? trainingFacilityLevel, int? ticketPrice, required int budget}) async => null;

  @override
  Future<void> updateFcmToken(String token) async {}
}

void main() {
  testWidgets('app starts', (WidgetTester tester) async {
    await tester.pumpWidget(
      SoccerManagerApp(
        gameProvider: GameProvider(repository: _TestGameRepository(), enableRealtime: false),
        initialHome: const Scaffold(body: Center(child: Text('Test Home'))),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Test Home'), findsOneWidget);
  });
}
