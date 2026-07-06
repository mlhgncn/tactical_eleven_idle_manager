import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';

class DevelopmentScreen extends StatelessWidget {
  const DevelopmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final club = provider.activeClub;

    if (provider.isLoading || club == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Kulüp Geliştirme')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                title: const Text('Stadyum Kapasitesi'),
                subtitle: Text('${club.stadiumCapacity}'),
                trailing: Builder(builder: (ctx) {
                  final newCapacity = club.stadiumCapacity + 500;
                  final cost = 1000 + (newCapacity ~/ 1000);
                  return ElevatedButton(
                    onPressed: provider.isBusy
                        ? null
                        : () async {
                            try {
                              await context.read<GameProvider>().upgradeClub(stadiumCapacity: newCapacity);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Stadyum başarıyla yükseltildi.'), backgroundColor: Colors.green),
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
                    child: Text('Yükselt ($cost GP)'),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('Tesis Seviyesi'),
                subtitle: Text('${club.trainingFacilityLevel}'),
                trailing: Builder(builder: (ctx) {
                  final newLevel = club.trainingFacilityLevel + 1;
                  final cost = 2000 + (newLevel * 1500);
                  return ElevatedButton(
                    onPressed: provider.isBusy
                          ? null
                          : () async {
                              try {
                                await context.read<GameProvider>().upgradeClub(trainingFacilityLevel: newLevel);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Tesis başarıyla yükseltildi.'), backgroundColor: Colors.green),
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
                    child: Text('Yükselt ($cost GP)'),
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
                  final cost = 500; // fixed in upgradeClub
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
                    child: Text('Yükselt ($cost GP)'),
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
