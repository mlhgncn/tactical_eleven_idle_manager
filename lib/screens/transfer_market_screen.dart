import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/free_agent_card.dart';
import '../widgets/transfer_market_card.dart';
import '../widgets/transfer_offer_card.dart';

const _positions = ['GK', 'CB', 'LB', 'RB', 'CDM', 'CM', 'CAM', 'LM', 'RM', 'ST', 'LW', 'RW'];

class TransferMarketScreen extends StatefulWidget {
  const TransferMarketScreen({super.key});

  @override
  State<TransferMarketScreen> createState() => _TransferMarketScreenState();
}

class _TransferMarketScreenState extends State<TransferMarketScreen> {
  String? _positionFilter;
  RangeValues _abilityRange = const RangeValues(0, 99);

  bool _matchesFilter(String position, int ability) {
    if (_positionFilter != null && position != _positionFilter) return false;
    if (ability < _abilityRange.start || ability > _abilityRange.end) return false;
    return true;
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ChoiceChip(
                  label: Text('transferMarket.allPositions'.tr()),
                  selected: _positionFilter == null,
                  onSelected: (_) => setState(() => _positionFilter = null),
                ),
                const SizedBox(width: 6),
                for (final pos in _positions) ...[
                  ChoiceChip(
                    label: Text(pos),
                    selected: _positionFilter == pos,
                    onSelected: (_) => setState(() => _positionFilter = pos),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          Row(
            children: [
              Text('transferMarket.abilityLabel'.tr(), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              Expanded(
                child: RangeSlider(
                  min: 0,
                  max: 99,
                  divisions: 33,
                  labels: RangeLabels('${_abilityRange.start.round()}', '${_abilityRange.end.round()}'),
                  values: _abilityRange,
                  onChanged: (values) => setState(() => _abilityRange = values),
                ),
              ),
              Text('${_abilityRange.start.round()}-${_abilityRange.end.round()}', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final activeClub = provider.activeClub;
    final isLoading = provider.isLoading;

    if (activeClub == null) {
      return Scaffold(
        appBar: AppBar(title: Text('transferMarket.title'.tr())),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'transferMarket.noClubMessage'.tr(),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final listings = provider.transferMarketItems
        .where((item) => _matchesFilter(item.playerPosition, item.currentAbility))
        .toList();
    final freeAgents = provider.freeAgents
        .where((player) => _matchesFilter(player.position, player.currentAbility))
        .toList();
    final incoming = provider.incomingTransferOffers;
    final outgoing = provider.outgoingTransferOffers;
    final pendingIncomingCount = provider.pendingIncomingOfferCount;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('transferMarket.title'.tr()),
          bottom: TabBar(
            tabs: [
              Tab(text: 'transferMarket.tabListed'.tr()),
              Tab(text: 'transferMarket.tabFreeAgents'.tr()),
              Tab(
                text: pendingIncomingCount > 0
                    ? 'transferMarket.tabOffersWithCount'.tr(namedArgs: {'count': pendingIncomingCount.toString()})
                    : 'transferMarket.tabOffers'.tr(),
              ),
            ],
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  Column(
                    children: [
                      _buildFilterBar(),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () => context.read<GameProvider>().refreshGameState(),
                          child: listings.isEmpty
                              ? ListView(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 80),
                                      child: Center(child: Text('transferMarket.noListedMatch'.tr())),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  itemCount: listings.length,
                                  itemBuilder: (context, index) {
                                    final item = listings[index];
                                    return TransferMarketCard(
                                      item: item,
                                      activeClubId: activeClub.id,
                                      onMakeOffer: (amount) async {
                                        try {
                                          await context.read<GameProvider>().makeTransferOffer(
                                                playerId: item.playerId,
                                                offerAmount: amount,
                                              );
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('transferMarket.offerSent'.tr())),
                                          );
                                        } catch (error) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
                                          );
                                        }
                                      },
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      _buildFilterBar(),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () => context.read<GameProvider>().refreshGameState(),
                          child: freeAgents.isEmpty
                              ? ListView(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 80),
                                      child: Center(child: Text('transferMarket.noFreeAgentMatch'.tr())),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  itemCount: freeAgents.length,
                                  itemBuilder: (context, index) {
                                    final player = freeAgents[index];
                                    return FreeAgentCard(
                                      player: player,
                                      onSign: () async {
                                        try {
                                          await context.read<GameProvider>().signFreeAgent(playerId: player.id);
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('transferMarket.playerJoinedSquad'.tr(namedArgs: {'name': player.name}))),
                                          );
                                        } catch (error) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
                                          );
                                        }
                                      },
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  ),
                  RefreshIndicator(
                    onRefresh: () => context.read<GameProvider>().refreshGameState(),
                    child: (incoming.isEmpty && outgoing.isEmpty)
                        ? ListView(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 80),
                                child: Center(child: Text('transferMarket.noOffersYet'.tr())),
                              ),
                            ],
                          )
                        : ListView(
                            padding: const EdgeInsets.only(top: 12, bottom: 24),
                            children: [
                              if (incoming.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Text('transferMarket.incomingOffers'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                for (final offer in incoming)
                                  TransferOfferCard(
                                    offer: offer,
                                    isIncoming: true,
                                    onRespond: (accept) async {
                                      try {
                                        await context.read<GameProvider>().respondToTransferOffer(
                                              offerId: offer.id,
                                              accept: accept,
                                            );
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(accept ? 'transferMarket.offerAccepted'.tr() : 'transferMarket.offerRejected'.tr())),
                                        );
                                      } catch (error) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
                                        );
                                      }
                                    },
                                  ),
                              ],
                              if (outgoing.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Text('transferMarket.outgoingOffers'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                for (final offer in outgoing)
                                  TransferOfferCard(
                                    offer: offer,
                                    isIncoming: false,
                                    onWithdraw: () async {
                                      try {
                                        await context.read<GameProvider>().withdrawTransferOffer(offerId: offer.id);
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('transferMarket.offerWithdrawn'.tr())),
                                        );
                                      } catch (error) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
                                        );
                                      }
                                    },
                                  ),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
