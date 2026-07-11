import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/player_fm.dart';
import '../models/transfer_market_item.dart';
import '../widgets/player_card.dart';

/// Read-only stats view for a player that isn't in the viewer's own squad
/// (transfer market listings, free agents seen from the market). Unlike
/// PlayerDetailScreen, this never shows development/training actions or
/// transfer-listing management - those only make sense for a club's own
/// players.
class PlayerStatsScreen extends StatelessWidget {
  const PlayerStatsScreen({super.key, required PlayerFM player, this.sellerClubName})
      : _player = player;

  factory PlayerStatsScreen.fromListing(TransferMarketItem item, {Key? key}) {
    return PlayerStatsScreen(
      key: key,
      player: PlayerFM(
        id: item.playerId,
        clubId: item.sellerClubId,
        name: item.playerName,
        position: item.playerPosition,
        age: item.age,
        currentAbility: item.currentAbility,
        potentialAbility: item.potentialAbility,
        morale: item.morale,
        fitness: item.fitness,
        finishing: item.finishing,
        passing: item.passing,
        tackling: item.tackling,
        composure: item.composure,
        determination: item.determination,
        consistency: item.consistency,
        injuryProneness: item.injuryProneness,
        formRating: item.formRating,
        injuryType: item.injuryType,
        injuryDurationWeeks: item.injuryDurationWeeks,
        isSuspended: item.isSuspended,
      ),
      sellerClubName: item.sellerClubDisplayName,
    );
  }

  final PlayerFM _player;
  final String? sellerClubName;

  @override
  Widget build(BuildContext context) {
    final player = _player;

    return Scaffold(
      appBar: AppBar(title: Text(player.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(child: PlayerCard(player: player)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(player.name, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('playerDetail.positionAge'.tr(namedArgs: {'position': player.position, 'age': player.age.toString()})),
                  if (sellerClubName != null) ...[
                    const SizedBox(height: 4),
                    Text('transferMarket.sellerClub'.tr(namedArgs: {'name': sellerClubName!})),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Text('playerDetail.caLabel'.tr(namedArgs: {'value': player.currentAbility.toString()})),
                      Text('playerDetail.paLabel'.tr(namedArgs: {'value': player.potentialAbility.toString()})),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Text('playerDetail.moraleLabel'.tr(namedArgs: {'value': player.morale.toString()})),
                      Text('playerDetail.fitnessLabel'.tr(namedArgs: {'value': player.fitness.toString()})),
                      Text('playerDetail.formLabel'.tr(namedArgs: {'value': player.formRating.toStringAsFixed(2)})),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('playerDetail.marketValueLabel'.tr(namedArgs: {'value': player.marketValueLabel})),
                  const SizedBox(height: 8),
                  Text('playerDetail.injuryLabel'.tr(namedArgs: {'value': player.hasActiveInjury ? player.injuryDisplayLabel : 'playerDetail.none'.tr()})),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('playerDetail.attributesTitle'.tr(), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _attributeRow(context, 'playerDetail.attrFinishing'.tr(), player.finishing),
                  _attributeRow(context, 'playerDetail.attrPassing'.tr(), player.passing),
                  _attributeRow(context, 'playerDetail.attrTackling'.tr(), player.tackling),
                  _attributeRow(context, 'playerDetail.attrComposure'.tr(), player.composure),
                  _attributeRow(context, 'playerDetail.attrDetermination'.tr(), player.determination),
                  _attributeRow(context, 'playerDetail.attrConsistency'.tr(), player.consistency),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _attributeRow(BuildContext context, String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          SizedBox(
            width: 160,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (value / 20).clamp(0, 1).toDouble(),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$value'),
        ],
      ),
    );
  }
}
