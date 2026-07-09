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
    final upgradingLabel = club.developmentUpgradeType == 'stadium' ? 'Stadyum genişletme' : 'Tesis yükseltmesi';
    final stadiumMaxed = club.stadiumCapacity >= 100000;
    final facilityMaxed = club.trainingFacilityLevel >= 10;

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
                  final newCapacity = club.stadiumCapacity + 500;
                  final cost = 2 * (1000 + (newCapacity ~/ 1000));
                  final durationDays = (1 + ((club.stadiumCapacity - 15000) ~/ 5000)).clamp(1, 14);
                  return ElevatedButton(
                    onPressed: provider.isBusy || isUpgrading
                        ? null
                        : () async {
                            try {
                              await context.read<GameProvider>().startClubDevelopment(
                                    upgradeType: 'stadium',
                                    targetValue: newCapacity,
                                  );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Stadyum genişletme başlatıldı.'), backgroundColor: Colors.green),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                                );
                              }
                            }
                          },
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
                  final cost = 2 * (2000 + (newLevel * 1500));
                  final durationDays = 2 * club.trainingFacilityLevel - 1;
                  return ElevatedButton(
                    onPressed: provider.isBusy || isUpgrading
                          ? null
                          : () async {
                              try {
                                await context.read<GameProvider>().startClubDevelopment(
                                      upgradeType: 'facility',
                                      targetValue: newLevel,
                                    );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Tesis yükseltmesi başlatıldı.'), backgroundColor: Colors.green),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                                  );
                                }
                              }
                            },
                    child: Text('Başlat ($cost GP, $durationDays gün)'),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('Bilet Fiyatı'),
                subtitle: Text('${club.ticketPrice} GP'),
                trailing: Builder(builder: (ctx) {
                  final newPrice = club.ticketPrice + 10;
                  const cost = 500;
                  return ElevatedButton(
                    onPressed: provider.isBusy
                          ? null
                          : () async {
                              try {
                                await context.read<GameProvider>().upgradeClub(ticketPrice: newPrice);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Bilet fiyatı başarıyla güncellendi.'), backgroundColor: Colors.green),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                                  );
                                }
                              }
                            },
                    child: const Text('Yükselt ($cost GP)'),
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
