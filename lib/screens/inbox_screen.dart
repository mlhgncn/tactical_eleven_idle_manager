import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

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
              children: const [
                Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: Text('Gelen kutunuz boş.')),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(message.title),
                    subtitle: Text(message.body),
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
                                    SnackBar(content: Text('Mesaj işaretlenemedi: $error')),
                                  );
                                }
                                return;
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Mesaj okundu olarak işaretlendi.')),
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
