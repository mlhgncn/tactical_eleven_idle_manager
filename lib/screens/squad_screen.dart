import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../providers/game_provider.dart';

class SquadScreen extends StatelessWidget {
  const SquadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final squad = provider.squadPlayers;
    final isLoading = provider.isLoading;

    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : squad.isEmpty
              ? Center(child: Text('No squad found'.tr()))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: squad.length,
                  itemBuilder: (context, index) {
                    final player = squad[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(player.name),
                        subtitle: Text('${player.position} • CA: ${player.currentAbility}'),
                        trailing: Text('Yaş: ${player.age}'),
                      ),
                    );
                  },
                ),
    );
  }
}
