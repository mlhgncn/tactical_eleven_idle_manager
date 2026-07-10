import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/player_fm.dart';
import '../providers/game_provider.dart';
import '../widgets/player_card.dart';
import '../widgets/themed_button.dart';
import '../widgets/timed_progress_bar.dart';

class PlayerDetailScreen extends StatefulWidget {
  const PlayerDetailScreen({super.key, required this.player});

  final PlayerFM player;

  @override
  State<PlayerDetailScreen> createState() => _PlayerDetailScreenState();
}

class _PlayerDetailScreenState extends State<PlayerDetailScreen> {
  bool isUpdating = false;
  bool isListing = false;
  bool isWithdrawing = false;
  late final TextEditingController _askingPriceController =
      TextEditingController(text: widget.player.marketValue.toString());

  @override
  void dispose() {
    _askingPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final player = provider.squadPlayers.firstWhere(
      (item) => item.id == widget.player.id,
      orElse: () => widget.player,
    );

    final playerIndex = provider.squadPlayers.indexWhere((item) => item.id == player.id);
    final isStarter = playerIndex >= 0 && playerIndex < 11;

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
                  const SizedBox(height: 8),
                  Text('playerDetail.positionAge'.tr(namedArgs: {'position': player.position, 'age': player.age.toString()})),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Text('playerDetail.caLabel'.tr(namedArgs: {'value': player.currentAbility.toString()})),
                      Text('playerDetail.paLabel'.tr(namedArgs: {'value': player.potentialAbility.toString()})),
                      Text('playerDetail.starterLabel'.tr(namedArgs: {'value': isStarter ? 'playerDetail.yes'.tr() : 'squad.benchLabel'.tr()})),
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
                  Text('playerDetail.salaryLabel'.tr(namedArgs: {'value': player.salaryLabel})),
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
                  Text('playerDetail.developmentTitle'.tr(), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (player.isDeveloping) ...[
                    TimedProgressBar(
                      completesAt: player.developmentCompletesAt!,
                      totalDuration: const Duration(hours: 2),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'playerDetail.devProgressNote'.tr(),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ] else if (player.currentAbility >= player.potentialAbility) ...[
                    Text('playerDetail.devMaxed'.tr()),
                  ] else ...[
                    Text(
                      'playerDetail.devDescription'.tr(),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    GoldButton(
                      isLoading: isUpdating,
                      onPressed: isUpdating ? null : () async {
                          setState(() => isUpdating = true);
                          try {
                            await provider.startPlayerDevelopment(playerId: player.id);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('playerDetail.devStarted'.tr())),
                            );
                          } catch (error) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
                            );
                          } finally {
                            if (mounted) {
                              setState(() => isUpdating = false);
                            }
                          }
                        },
                      label: 'playerDetail.startDevelopmentButton'.tr(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildTransferCard(context, provider, player),
        ],
      ),
    );
  }

  Widget _buildTransferCard(BuildContext context, GameProvider provider, PlayerFM player) {
    final matchingListings = provider.transferMarketItems.where((item) => item.playerId == player.id).toList();
    final activeListing = matchingListings.isEmpty ? null : matchingListings.first;
    final pendingOffers = provider.incomingTransferOffers
        .where((offer) => offer.playerId == player.id && offer.isPending)
        .toList();

    final offersCard = pendingOffers.isEmpty
        ? null
        : Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('transferMarket.incomingOffers'.tr(), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  for (final offer in pendingOffers) ...[
                    Text('playerDetail.offerLine'.tr(namedArgs: {'club': offer.fromClubName, 'amount': offer.offerAmount.toString()})),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GlassButton(
                            onPressed: () async {
                              try {
                                await provider.respondToTransferOffer(offerId: offer.id, accept: true);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('transferMarket.offerAccepted'.tr())),
                                );
                              } catch (error) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
                                );
                              }
                            },
                            label: 'transferOffer.accept'.tr(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GlassButton(
                            onPressed: () async {
                              try {
                                await provider.respondToTransferOffer(offerId: offer.id, accept: false);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('transferMarket.offerRejected'.tr())),
                                );
                              } catch (error) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
                                );
                              }
                            },
                            label: 'transferOffer.reject'.tr(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          );

    if (activeListing != null) {
      final listingCard = Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('transferMarket.title'.tr(), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Text('playerDetail.askingPriceLine'.tr(namedArgs: {'price': activeListing.askingPrice.toString()})),
              const SizedBox(height: 4),
              Text('playerDetail.otherClubsCanOffer'.tr()),
              const SizedBox(height: 12),
              GlassButton(
                isLoading: isWithdrawing,
                onPressed: isWithdrawing
                    ? null
                    : () async {
                        setState(() => isWithdrawing = true);
                        try {
                          await provider.withdrawTransferListing(playerId: player.id);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('playerDetail.removedFromMarket'.tr())),
                          );
                        } catch (error) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.toString())),
                          );
                        } finally {
                          if (mounted) setState(() => isWithdrawing = false);
                        }
                      },
                label: 'playerDetail.removeFromListingButton'.tr(),
              ),
            ],
          ),
        ),
      );
      if (offersCard == null) return listingCard;
      return Column(children: [offersCard, const SizedBox(height: 16), listingCard]);
    }

    final listingForm = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('transferMarket.title'.tr(), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _askingPriceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'playerDetail.askingPriceFieldLabel'.tr()),
            ),
            const SizedBox(height: 12),
            GlassButton(
              isLoading: isListing,
              onPressed: isListing
                  ? null
                  : () async {
                      final askingPrice = int.tryParse(_askingPriceController.text.trim());
                      if (askingPrice == null || askingPrice <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('playerDetail.enterValidPrice'.tr())),
                        );
                        return;
                      }
                      setState(() => isListing = true);
                      try {
                        await provider.listPlayerForTransfer(
                          playerId: player.id,
                          askingPrice: askingPrice,
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('playerDetail.listedOnMarket'.tr())),
                        );
                      } catch (error) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      } finally {
                        if (mounted) setState(() => isListing = false);
                      }
                    },
              label: 'playerDetail.listForTransferButton'.tr(),
            ),
          ],
        ),
      ),
    );

    if (offersCard == null) return listingForm;
    return Column(children: [offersCard, const SizedBox(height: 16), listingForm]);
  }
}
