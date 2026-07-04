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

    if (messages.isEmpty) {
      return const Center(child: Text('Gelen kutunuz boş.'));
    }

    return ListView.builder(
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
                      await context.read<GameProvider>().markMessageAsRead(message.id);
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
    );
  }
}
