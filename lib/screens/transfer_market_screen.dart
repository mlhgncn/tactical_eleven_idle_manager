import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../widgets/transfer_market_card.dart';

class TransferMarketScreen extends StatelessWidget {
  const TransferMarketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final activeClub = provider.activeClub;
    final items = provider.transferMarketItems;
    final isLoading = provider.isLoading;
    final isSyncing = provider.isSyncing;

    if (activeClub == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Canlı Transfer Pazarı')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Transfer pazarına erişmek için önce bir kulüp seçmeli veya oluşturmalısınız.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Canlı Transfer Pazarı')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => context.read<GameProvider>().refreshGameState(),
              child: Stack(
                children: [
                  items.isEmpty
                      ? ListView(
                          children: const [
                            Padding(
                              padding: EdgeInsets.only(top: 80),
                              child: Center(child: Text('Şu anda açık transfer yok.')),
                            ),
                          ],
                        )
                      : ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return TransferMarketCard(
                              item: item,
                              activeClubId: activeClub.id,
                              onBidPressed: item.isSold
                                  ? null
                                  : () async {
                                      try {
                                        await context.read<GameProvider>().placeBid(
                                              marketId: item.id,
                                              bidAmount: item.currentHighestBid + 100,
                                            );
                                      } catch (error) {
                                        if (!context.mounted) return;
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
            ),
    );
  }
}
