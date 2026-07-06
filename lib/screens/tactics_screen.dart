import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/tactics.dart';
import '../providers/game_provider.dart';

class TacticsScreen extends StatefulWidget {
  const TacticsScreen({super.key});

  @override
  State<TacticsScreen> createState() => _TacticsScreenState();
}

class _TacticsScreenState extends State<TacticsScreen> {
  late Tactics _tactics;
  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<GameProvider>();
    final squad = provider.squadPlayers;
    final saved = provider.tactics;

    if (saved != null) {
      _tactics = saved;
      return;
    }

    final defaultPlayer = squad.isNotEmpty ? squad.first.id : '';
    _tactics = Tactics(
      clubId: provider.activeClub?.id ?? 'club',
      captainId: defaultPlayer,
      penaltyTakerId: defaultPlayer,
    );
  }

  Future<void> _saveTactics() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      await context.read<GameProvider>().saveTactics(_tactics);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Taktikler Supabase\'e kaydedildi.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Taktikler kaydedilemedi: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final squad = provider.squadPlayers;

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (squad.isEmpty) {
      return const Center(child: Text('Kadro yüklenemedi.'));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Taktik Paneli', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Formasyon', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButton<Formation>(
                      value: _tactics.formation,
                      isExpanded: true,
                      items: Formation.values
                          .map(
                            (formation) => DropdownMenuItem(
                              value: formation,
                              child: Text(formation.name.toUpperCase()),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _tactics = Tactics(
                              clubId: _tactics.clubId,
                              formation: value,
                              mentality: _tactics.mentality,
                              captainId: _tactics.captainId,
                              penaltyTakerId: _tactics.penaltyTakerId,
                            ));
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Mentalite', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButton<Mentality>(
                      value: _tactics.mentality,
                      isExpanded: true,
                      items: Mentality.values
                          .map(
                            (mentality) => DropdownMenuItem(
                              value: mentality,
                              child: Text(mentality.name.toUpperCase()),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _tactics = Tactics(
                              clubId: _tactics.clubId,
                              formation: _tactics.formation,
                              mentality: value,
                              captainId: _tactics.captainId,
                              penaltyTakerId: _tactics.penaltyTakerId,
                            ));
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Kaptan', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: _tactics.captainId.isEmpty ? squad.first.id : _tactics.captainId,
                      isExpanded: true,
                      items: squad
                          .map(
                            (player) => DropdownMenuItem(
                              value: player.id,
                              child: Text(player.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _tactics = Tactics(
                              clubId: _tactics.clubId,
                              formation: _tactics.formation,
                              mentality: _tactics.mentality,
                              captainId: value,
                              penaltyTakerId: _tactics.penaltyTakerId,
                            ));
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Penaltı Atıcısı', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: _tactics.penaltyTakerId.isEmpty ? squad.first.id : _tactics.penaltyTakerId,
                      isExpanded: true,
                      items: squad
                          .map(
                            (player) => DropdownMenuItem(
                              value: player.id,
                              child: Text(player.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _tactics = Tactics(
                              clubId: _tactics.clubId,
                              formation: _tactics.formation,
                              mentality: _tactics.mentality,
                              captainId: _tactics.captainId,
                              penaltyTakerId: value,
                            ));
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveTactics,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Taktikleri Kaydet'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
