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
                trailing: ElevatedButton(
                  onPressed: provider.isBusy
                      ? null
                      : () async {
                          await context.read<GameProvider>().upgradeClub(stadiumCapacity: club.stadiumCapacity + 500);
                        },
                  child: const Text('Yükselt (500 GP)'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('Tesis Seviyesi'),
                subtitle: Text('${club.trainingFacilityLevel}'),
                trailing: ElevatedButton(
                  onPressed: provider.isBusy
                      ? null
                      : () async {
                          await context.read<GameProvider>().upgradeClub(trainingFacilityLevel: club.trainingFacilityLevel + 1);
                        },
                  child: const Text('Yükselt (500 GP)'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('Bilet Fiyatı'),
                subtitle: Text('${club.ticketPrice} GP'),
                trailing: ElevatedButton(
                  onPressed: provider.isBusy
                      ? null
                      : () async {
                          await context.read<GameProvider>().upgradeClub(ticketPrice: club.ticketPrice + 10);
                        },
                  child: const Text('Yükselt (500 GP)'),
                ),
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
