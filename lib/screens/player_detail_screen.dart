import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/player_fm.dart';
import '../providers/game_provider.dart';
import '../widgets/player_card.dart';
import '../widgets/themed_button.dart';

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
                  Text('${player.position} • Yaş: ${player.age}'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Text('CA: ${player.currentAbility}'),
                      Text('PA: ${player.potentialAbility}'),
                      Text('Başlangıç: ${isStarter ? 'Evet' : 'Yedek'}'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Text('Moral: ${player.morale}'),
                      Text('Fitness: ${player.fitness}'),
                      Text('Form: ${player.formRating.toStringAsFixed(2)}'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Maaş: ${player.salaryLabel}'),
                  Text('Piyasa Değeri: ${player.marketValueLabel}'),
                  const SizedBox(height: 8),
                  Text('Sakatlık: ${player.hasActiveInjury ? player.injuryDisplayLabel : 'yok'}'),
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
                  Text('Gelişim', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (player.isDeveloping) ...[
                    Text(
                      'Gelişim sürüyor. Tamamlanma: ${_formatRemaining(player.developmentCompletesAt!)}',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Uygulamadan çıksan bile süre sunucuda ilerlemeye devam eder.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ] else if (player.currentAbility >= player.potentialAbility) ...[
                    const Text('Bu oyuncu potansiyeline ulaştı, artık gelişim uygulanamaz.'),
                  ] else ...[
                    const Text(
                      'Bir gelişim seansı 2 saat sürer ve gücü %1-%3 arasında rastgele artırır.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
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
                              const SnackBar(content: Text('Gelişim başlatıldı (2 saat)')),
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
                      label: 'Gelişimi başlat',
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

  String _formatRemaining(DateTime completesAt) {
    final remaining = completesAt.difference(DateTime.now());
    if (remaining.isNegative) return 'birazdan';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    if (hours > 0) return '$hours sa $minutes dk';
    return '$minutes dk';
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
                  Text('Gelen Teklifler', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  for (final offer in pendingOffers) ...[
                    Text('${offer.fromClubName}: ${offer.offerAmount} GP'),
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
                                  const SnackBar(content: Text('Teklif kabul edildi')),
                                );
                              } catch (error) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
                                );
                              }
                            },
                            label: 'Kabul Et',
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
                                  const SnackBar(content: Text('Teklif reddedildi')),
                                );
                              } catch (error) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
                                );
                              }
                            },
                            label: 'Reddet',
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
              Text('Transfer Pazarı', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Text('İstenen fiyat: ${activeListing.askingPrice} GP'),
              const SizedBox(height: 4),
              const Text('Başka kulüpler bu oyuncu için teklif verebilir.'),
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
                            const SnackBar(content: Text('Oyuncu transfer pazarından kaldırıldı')),
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
                label: 'Listeden Kaldır',
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
            Text('Transfer Pazarı', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _askingPriceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'İstenen fiyat (GP)'),
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
                          const SnackBar(content: Text('Geçerli bir fiyat girin')),
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
                          const SnackBar(content: Text('Oyuncu transfer pazarına çıkarıldı')),
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
              label: 'Transfere Çıkar',
            ),
          ],
        ),
      ),
    );

    if (offersCard == null) return listingForm;
    return Column(children: [offersCard, const SizedBox(height: 16), listingForm]);
  }
}
