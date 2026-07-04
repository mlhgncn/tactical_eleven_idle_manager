import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';

class TransferHistoryScreen extends StatelessWidget {
  const TransferHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final items = provider.transferMarketItems;

    return Scaffold(
      appBar: AppBar(title: const Text('Transfer Geçmişi')),
      body: items.isEmpty
          ? const Center(child: Text('Transfer geçmişi bulunamadı.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text('${item.playerName} (${item.playerPosition})'),
                    subtitle: Text('En yüksek teklif: ${item.currentHighestBid} GP'),
                    trailing: Text(item.isSold ? 'Satıldı' : 'Açık'),
                  ),
                );
              },
            ),
    );
  }
}
