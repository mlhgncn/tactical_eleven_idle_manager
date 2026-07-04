import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';

class ClubFinanceScreen extends StatelessWidget {
  const ClubFinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final club = provider.activeClub;
    final isLoading = provider.isLoading;

    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : club == null
              ? const Center(child: Text('Aktif kulüp bulunamadı.'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kulüp Finansları', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 16),
                      Card(
                        child: ListTile(
                          title: const Text('Bütçe'),
                          trailing: Text('${club.budget} GP'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Card(
                        child: ListTile(
                          title: const Text('Stadyum Kapasitesi'),
                          trailing: Text('${club.stadiumCapacity}'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Card(
                        child: ListTile(
                          title: const Text('Bilet Fiyatı'),
                          trailing: Text('${club.ticketPrice} GP'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Card(
                        child: ListTile(
                          title: const Text('Tesis Seviyesi'),
                          trailing: Text('${club.trainingFacilityLevel}'),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
