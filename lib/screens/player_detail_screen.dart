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
  int minutesPlayed = 90;
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
                  Text('Dakika: $minutesPlayed'),
                  Slider(
                    min: 0,
                    max: 180,
                    divisions: 6,
                    value: minutesPlayed.toDouble(),
                    onChanged: (value) => setState(() => minutesPlayed = value.toInt()),
                  ),
                  const SizedBox(height: 12),
                  GoldButton(
                    isLoading: isUpdating,
                    onPressed: isUpdating ? null : () async {
                        setState(() => isUpdating = true);
                        try {
                          await provider.applyPlayerDevelopmentToPlayer(
                            playerId: player.id,
                            minutesPlayed: minutesPlayed,
                            trainingFacilityLevel: provider.activeClub?.trainingFacilityLevel ?? 1,
                            morale: player.morale,
                            formRating: player.formRating,
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Gelişim güncellendi')),
                          );
                        } finally {
                          if (mounted) {
                            setState(() => isUpdating = false);
                          }
                        }
                      },
                    label: 'Gelişimi uygula',
                  ),
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
    final matchingListings =
        provider.transferMarketItems.where((item) => item.playerId == player.id && !item.isSold).toList();
    final activeListing = matchingListings.isEmpty ? null : matchingListings.first;

    if (activeListing != null) {
      final hasBid = activeListing.highestBidderId != null;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Transfer Pazarı', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Text('İstenen/en yüksek teklif: ${activeListing.currentHighestBid} GP'),
              const SizedBox(height: 4),
              Text(hasBid
                  ? 'Bu oyuncuya zaten bir teklif verildi, listeden kaldırılamaz.'
                  : 'Henüz teklif yok, istersen listeden geri çekebilirsin.'),
              const SizedBox(height: 12),
              GlassButton(
                isLoading: isWithdrawing,
                onPressed: hasBid || isWithdrawing
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
    }

    return Card(
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
  }
}
