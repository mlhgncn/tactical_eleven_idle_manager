import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/player_fm.dart';
import '../providers/game_provider.dart';

class PlayerDetailScreen extends StatefulWidget {
  const PlayerDetailScreen({super.key, required this.player});

  final PlayerFM player;

  @override
  State<PlayerDetailScreen> createState() => _PlayerDetailScreenState();
}

class _PlayerDetailScreenState extends State<PlayerDetailScreen> {
  int minutesPlayed = 90;
  bool isUpdating = false;

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
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
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
                      child: isUpdating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Gelişimi uygula'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
