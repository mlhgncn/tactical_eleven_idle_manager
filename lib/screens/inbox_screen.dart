import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import 'player_stats_screen.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  Future<void> _openRelatedPlayer(BuildContext context, String playerId) async {
    final provider = context.read<GameProvider>();
    final player = await provider.loadPlayerById(playerId);
    if (!context.mounted) return;
    if (player == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('inbox.playerUnavailable'.tr())),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerStatsScreen(player: player)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final messages = provider.inboxMessages;

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => context.read<GameProvider>().refreshGameState(),
      child: messages.isEmpty
          ? ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: Center(child: Text('inbox.empty'.tr())),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final hasPlayerLink = message.relatedPlayerId != null;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(message.title),
                    subtitle: Text(message.body),
                    onTap: hasPlayerLink ? () => _openRelatedPlayer(context, message.relatedPlayerId!) : null,
                    trailing: IconButton(
                      icon: Icon(
                        message.isRead ? Icons.mark_email_read : Icons.mark_email_unread,
                        color: message.isRead ? Colors.greenAccent : Colors.orangeAccent,
                      ),
                      onPressed: message.isRead
                          ? null
                          : () async {
                              try {
                                await context.read<GameProvider>().markMessageAsRead(message.id);
                              } catch (error) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('inbox.markFailed'.tr(namedArgs: {'error': error.toString()}))),
                                  );
                                }
                                return;
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('inbox.markedAsRead'.tr())),
                                );
                              }
                            },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
