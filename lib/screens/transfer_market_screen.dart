import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/free_agent_card.dart';
import '../widgets/transfer_market_card.dart';
import '../widgets/transfer_offer_card.dart';
import 'player_stats_screen.dart';

const _positions = ['GK', 'CB', 'LB', 'RB', 'CDM', 'CM', 'CAM', 'LM', 'RM', 'ST', 'LW', 'RW'];

class TransferMarketScreen extends StatefulWidget {
  const TransferMarketScreen({super.key});

  @override
  State<TransferMarketScreen> createState() => _TransferMarketScreenState();
}

class _TransferMarketScreenState extends State<TransferMarketScreen> {
  String? _positionFilter;
  RangeValues _abilityRange = const RangeValues(0, 99);
  final _searchController = TextEditingController();
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  bool _matchesFilter(String position, int ability) {
    if (_positionFilter != null && position != _positionFilter) return false;
    if (ability < _abilityRange.start || ability > _abilityRange.end) return false;
    return true;
  }

  /// Search matches either the player's name or their club's name
  /// (case-insensitive substring), per "Kulüp Adı ve Oyuncu Adı arama
  /// motoru". Empty search always matches.
  bool _matchesSearch(String playerName, String? clubName) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    return playerName.toLowerCase().contains(query) || (clubName?.toLowerCase().contains(query) ?? false);
  }

  bool _matchesPrice(int price) {
    final min = int.tryParse(_minPriceController.text.trim());
    final max = int.tryParse(_maxPriceController.text.trim());
    if (min != null && price < min) return false;
    if (max != null && price > max) return false;
    return true;
  }

  Future<void> _showReofferDialog(BuildContext context, String playerId, String playerName, int previousAmount) async {
    final controller = TextEditingController(text: previousAmount.toString());
    final amount = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('transferMarket.offerDialogTitle'.tr(namedArgs: {'playerName': playerName})),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'transferMarket.offerAmountLabel'.tr()),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              Navigator.of(dialogContext).pop(value);
            },
            child: Text('transferMarket.submitOffer'.tr()),
          ),
        ],
      ),
    );

    if (amount == null || amount <= 0 || !context.mounted) return;
    try {
      await context.read<GameProvider>().makeTransferOffer(playerId: playerId, offerAmount: amount);
      if (!context.mounted) return;
      AppSnackBar.showSuccess(context, 'transferMarket.offerSent'.tr());
    } catch (error) {
      if (!context.mounted) return;
      AppSnackBar.showErrorFromException(context, error);
    }
  }

  Widget _buildFilterBar({bool showPriceFilter = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'transferMarket.searchHint'.tr(),
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          if (showPriceFilter) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minPriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'transferMarket.minPriceHint'.tr(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _maxPriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'transferMarket.maxPriceHint'.tr(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
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
        .where((item) =>
            _matchesFilter(item.playerPosition, item.currentAbility) &&
            _matchesSearch(item.playerName, item.sellerClubName) &&
            _matchesPrice(item.askingPrice))
        .toList();
    final freeAgents = provider.freeAgents
        .where((player) => _matchesFilter(player.position, player.currentAbility) && _matchesSearch(player.name, null))
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
                      _buildFilterBar(showPriceFilter: true),
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
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => PlayerStatsScreen.fromListing(item)),
                                        );
                                      },
                                      onWithdraw: () async {
                                        try {
                                          await context.read<GameProvider>().withdrawTransferListing(playerId: item.playerId);
                                          if (!context.mounted) return;
                                          AppSnackBar.showSuccess(context, 'transferMarket.listingRemoved'.tr());
                                        } catch (error) {
                                          if (!context.mounted) return;
                                          AppSnackBar.showErrorFromException(context, error);
                                        }
                                      },
                                      onMakeOffer: (amount) async {
                                        try {
                                          await context.read<GameProvider>().makeTransferOffer(
                                                playerId: item.playerId,
                                                offerAmount: amount,
                                              );
                                          if (!context.mounted) return;
                                          AppSnackBar.showSuccess(context, 'transferMarket.offerSent'.tr());
                                        } catch (error) {
                                          if (!context.mounted) return;
                                          AppSnackBar.showErrorFromException(context, error);
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
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => PlayerStatsScreen(player: player)),
                                        );
                                      },
                                      onSign: () async {
                                        try {
                                          await context.read<GameProvider>().signFreeAgent(playerId: player.id);
                                          if (!context.mounted) return;
                                          AppSnackBar.showSuccess(context, 'transferMarket.playerJoinedSquad'.tr(namedArgs: {'name': player.name}));
                                        } catch (error) {
                                          if (!context.mounted) return;
                                          AppSnackBar.showErrorFromException(context, error);
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
                                        AppSnackBar.showSuccess(context, accept ? 'transferMarket.offerAccepted'.tr() : 'transferMarket.offerRejected'.tr());
                                      } catch (error) {
                                        if (!context.mounted) return;
                                        AppSnackBar.showErrorFromException(context, error);
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
                                        AppSnackBar.showSuccess(context, 'transferMarket.offerWithdrawn'.tr());
                                      } catch (error) {
                                        if (!context.mounted) return;
                                        AppSnackBar.showErrorFromException(context, error);
                                      }
                                    },
                                    onReoffer: () => _showReofferDialog(context, offer.playerId, offer.playerName, offer.offerAmount),
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
