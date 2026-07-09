import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../widgets/free_agent_card.dart';
import '../widgets/transfer_market_card.dart';
import '../widgets/transfer_offer_card.dart';

class TransferMarketScreen extends StatelessWidget {
  const TransferMarketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final activeClub = provider.activeClub;
    final isLoading = provider.isLoading;

    if (activeClub == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transfer Pazarı')),
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

    final listings = provider.transferMarketItems;
    final freeAgents = provider.freeAgents;
    final incoming = provider.incomingTransferOffers;
    final outgoing = provider.outgoingTransferOffers;
    final pendingIncomingCount = provider.pendingIncomingOfferCount;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Transfer Pazarı'),
          bottom: TabBar(
            tabs: [
              const Tab(text: 'Listelenen'),
              const Tab(text: 'Serbest Oyuncular'),
              Tab(text: pendingIncomingCount > 0 ? 'Teklifler ($pendingIncomingCount)' : 'Teklifler'),
            ],
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  RefreshIndicator(
                    onRefresh: () => context.read<GameProvider>().refreshGameState(),
                    child: listings.isEmpty
                        ? ListView(
                            children: const [
                              Padding(
                                padding: EdgeInsets.only(top: 80),
                                child: Center(child: Text('Şu anda listelenen oyuncu yok.')),
                              ),
                            ],
                          )
                        : ListView.builder(
                            itemCount: listings.length,
                            itemBuilder: (context, index) {
                              final item = listings[index];
                              return TransferMarketCard(
                                item: item,
                                activeClubId: activeClub.id,
                                onMakeOffer: (amount) async {
                                  try {
                                    await context.read<GameProvider>().makeTransferOffer(
                                          playerId: item.playerId,
                                          offerAmount: amount,
                                        );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Teklif gönderildi')),
                                    );
                                  } catch (error) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                  ),
                  RefreshIndicator(
                    onRefresh: () => context.read<GameProvider>().refreshGameState(),
                    child: freeAgents.isEmpty
                        ? ListView(
                            children: const [
                              Padding(
                                padding: EdgeInsets.only(top: 80),
                                child: Center(child: Text('Şu anda serbest oyuncu yok.')),
                              ),
                            ],
                          )
                        : ListView.builder(
                            itemCount: freeAgents.length,
                            itemBuilder: (context, index) {
                              final player = freeAgents[index];
                              return FreeAgentCard(
                                player: player,
                                onSign: () async {
                                  try {
                                    await context.read<GameProvider>().signFreeAgent(playerId: player.id);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('${player.name} kadroya katıldı')),
                                    );
                                  } catch (error) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                  ),
                  RefreshIndicator(
                    onRefresh: () => context.read<GameProvider>().refreshGameState(),
                    child: (incoming.isEmpty && outgoing.isEmpty)
                        ? ListView(
                            children: const [
                              Padding(
                                padding: EdgeInsets.only(top: 80),
                                child: Center(child: Text('Henüz bir teklif yok.')),
                              ),
                            ],
                          )
                        : ListView(
                            padding: const EdgeInsets.only(top: 12, bottom: 24),
                            children: [
                              if (incoming.isNotEmpty) ...[
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Text('Gelen Teklifler', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                for (final offer in incoming)
                                  TransferOfferCard(
                                    offer: offer,
                                    isIncoming: true,
                                    onRespond: (accept) async {
                                      try {
                                        await context.read<GameProvider>().respondToTransferOffer(
                                              offerId: offer.id,
                                              accept: accept,
                                            );
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(accept ? 'Teklif kabul edildi' : 'Teklif reddedildi')),
                                        );
                                      } catch (error) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
                                        );
                                      }
                                    },
                                  ),
                              ],
                              if (outgoing.isNotEmpty) ...[
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Text('Gönderdiğim Teklifler', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                for (final offer in outgoing)
                                  TransferOfferCard(
                                    offer: offer,
                                    isIncoming: false,
                                    onWithdraw: () async {
                                      try {
                                        await context.read<GameProvider>().withdrawTransferOffer(offerId: offer.id);
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Teklif geri çekildi')),
                                        );
                                      } catch (error) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
                                        );
                                      }
                                    },
                                  ),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
