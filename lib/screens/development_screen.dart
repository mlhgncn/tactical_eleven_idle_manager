import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';

class DevelopmentScreen extends StatelessWidget {
  const DevelopmentScreen({super.key});

  String _formatRemaining(DateTime completesAt) {
    final remaining = completesAt.difference(DateTime.now());
    if (remaining.isNegative) return 'birazdan';
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    if (days > 0) return '$days gün $hours sa';
    final minutes = remaining.inMinutes % 60;
    return '$hours sa $minutes dk';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final club = provider.activeClub;

    if (provider.isLoading || club == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isUpgrading = club.isDevelopmentUpgrading;
    final upgradingLabel = switch (club.developmentUpgradeType) {
      'stadium' => 'Stadyum genişletme',
      'facility' => 'Tesis yükseltmesi',
      _ => 'Bilet fiyatı güncellemesi',
    };
    final stadiumMaxed = club.stadiumCapacity >= 100000;
    final facilityMaxed = club.trainingFacilityLevel >= 10;
    final ticketMaxed = club.ticketPriceLevel >= 10;

    Future<void> startUpgrade(String upgradeType, int targetValue, String startedMessage) async {
      try {
        await context.read<GameProvider>().startClubDevelopment(
              upgradeType: upgradeType,
              targetValue: targetValue,
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(startedMessage), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Kulüp Geliştirme')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isUpgrading) ...[
              Card(
                color: Colors.amber.withValues(alpha: 0.12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('İnşaat sürüyor: $upgradingLabel', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('Tamamlanmasına kalan süre: ${_formatRemaining(club.developmentCompletesAt!)}'),
                      const SizedBox(height: 4),
                      const Text(
                        'Uygulama kapalıyken de süre ilerler.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              child: ListTile(
                title: const Text('Stadyum Kapasitesi'),
                subtitle: Text(stadiumMaxed ? '${club.stadiumCapacity} (maksimum)' : '${club.stadiumCapacity}'),
                trailing: Builder(builder: (ctx) {
                  if (stadiumMaxed) {
                    return const Chip(label: Text('MAX'));
                  }
                  const increment = 2500;
                  final newCapacity = club.stadiumCapacity + increment;
                  final cost = (increment * 15) + (club.stadiumCapacity * increment) ~/ 50000;
                  final durationDays = (1 + ((club.stadiumCapacity - 15000) ~/ 10000)).clamp(1, 14);
                  return ElevatedButton(
                    onPressed: provider.isBusy || isUpgrading
                        ? null
                        : () => startUpgrade('stadium', newCapacity, 'Stadyum genişletme başlatıldı.'),
                    child: Text('Başlat ($cost GP, $durationDays gün)'),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('Tesis Seviyesi'),
                subtitle: Text(facilityMaxed ? '${club.trainingFacilityLevel} (maksimum)' : '${club.trainingFacilityLevel}'),
                trailing: Builder(builder: (ctx) {
                  if (facilityMaxed) {
                    return const Chip(label: Text('MAX'));
                  }
                  final newLevel = club.trainingFacilityLevel + 1;
                  final cost = newLevel * 15000;
                  final durationDays = 2 * club.trainingFacilityLevel - 1;
                  return ElevatedButton(
                    onPressed: provider.isBusy || isUpgrading
                        ? null
                        : () => startUpgrade('facility', newLevel, 'Tesis yükseltmesi başlatıldı.'),
                    child: Text('Başlat ($cost GP, $durationDays gün)'),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('Bilet Fiyatı'),
                subtitle: Text(ticketMaxed
                    ? '${club.ticketPrice} GP (maksimum)'
                    : '${club.ticketPrice} GP (seviye ${club.ticketPriceLevel}/10)'),
                trailing: Builder(builder: (ctx) {
                  if (ticketMaxed) {
                    return const Chip(label: Text('MAX'));
                  }
                  final newLevel = club.ticketPriceLevel + 1;
                  final newPrice = 20 + (newLevel - 1) * 8;
                  final cost = newLevel * 6000;
                  final durationDays = 2 * club.ticketPriceLevel - 1;
                  return ElevatedButton(
                    onPressed: provider.isBusy || isUpgrading
                        ? null
                        : () => startUpgrade('ticket_price', newLevel, 'Bilet fiyatı güncellemesi başlatıldı ($newPrice GP\'ye).'),
                    child: Text('Başlat ($cost GP, $durationDays gün)'),
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),
            Text('Bütçe: ${club.budget} GP', style: Theme.of(context).textTheme.headlineSmall),
            if (provider.isBusy) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}
