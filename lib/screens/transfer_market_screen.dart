import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../widgets/transfer_market_card.dart';

class TransferMarketScreen extends StatelessWidget {
  const TransferMarketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final items = provider.transferMarketItems;
    final isLoading = provider.isLoading;
    final isSyncing = provider.isSyncing;

    return Scaffold(
      appBar: AppBar(title: const Text('Canlı Transfer Pazarı')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(child: Text('Şu anda açık transfer yok.'))
              : Stack(
                  children: [
                    ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return TransferMarketCard(
                          item: item,
                          onBidPressed: item.isSold
                              ? null
                              : () async {
                                  try {
                                    await context.read<GameProvider>().placeBid(
                                          marketId: item.id,
                                          bidAmount: item.currentHighestBid + 100,
                                        );
                                  } catch (error) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(error.toString())),
                                    );
                                  }
                                },
                        );
                      },
                    ),
                    if (isSyncing)
                      const Positioned(
                        right: 16,
                        top: 16,
                        child: Chip(label: Text('Senkrone ediliyor...')),
                      ),
                  ],
                ),
    );
  }
}
