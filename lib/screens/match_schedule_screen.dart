import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';

class MatchScheduleScreen extends StatelessWidget {
  const MatchScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final fixtures = provider.fixtures;
    final results = provider.results;

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TabBar(
              tabs: const [
                Tab(text: 'Takvim'),
                Tab(text: 'Sonuçlar'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                fixtures.isEmpty
                    ? const Center(child: Text('Yaklaşan maç yok.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: fixtures.length,
                        itemBuilder: (context, index) {
                          final fixture = fixtures[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text('${fixture.opponentName}'),
                              subtitle: Text('${fixture.kickoff.toLocal()}'.split('.').first),
                              trailing: Text(fixture.isHome ? 'Deplasman' : 'Ev'),
                            ),
                          );
                        },
                      ),
                results.isEmpty
                    ? const Center(child: Text('Geçmiş maç yok.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final result = results[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Sonuç: ${result.homeScore} - ${result.awayScore}', style: Theme.of(context).textTheme.titleMedium),
                                  const SizedBox(height: 8),
                                  Text('Toplam şutlar: ${result.homeShots} - ${result.awayShots}'),
                                  Text('Possession: ${result.homePossession}%'),
                                  const SizedBox(height: 10),
                                  Text('Özet:', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  ...result.commentary.map((line) => Text('• $line')),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
