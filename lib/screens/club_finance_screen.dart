import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import 'development_screen.dart';
import 'sponsor_upgrade_screen.dart';
import 'transfer_history_screen.dart';
import 'financial_transactions_screen.dart';

class ClubFinanceScreen extends StatelessWidget {
  const ClubFinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final club = provider.activeClub;
    final isLoading = provider.isLoading;

    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (club == null) {
      return const Scaffold(
        body: Center(child: Text('Aktif kulüp bulunamadı.')),
      );
    }

    // Maç ekonomisi hesaplaması (kazanma senaryosu)
    final matchEconomy = provider.calculateMatchEconomy(isWin: true);
    final stadiumRevenue = matchEconomy['stadiumRevenue'] ?? 0;
    final sponsorRevenue = matchEconomy['sponsorRevenue'] ?? 0;
    final matchBonus = matchEconomy['matchBonus'] ?? 0;
    final playerWages = matchEconomy['playerWages'] ?? 0;
    final maintenanceCost = matchEconomy['maintenanceCost'] ?? 0;
    final totalRevenue = matchEconomy['totalRevenue'] ?? 0;
    final totalExpense = matchEconomy['totalExpense'] ?? 0;
    final netIncome = matchEconomy['netIncome'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kulüp Finansları'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mevcut Bütçe
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mevcut Bütçe',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${club.budget} GP',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Rezerve Bütçe: ${club.blockedBudget} GP',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      'Kullanılabilir Bütçe: ${club.budget - club.blockedBudget} GP',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Ekonomi Özeti (Maç Başına)
            Text(
              'Maç Başına Ekonomi (Kazanma)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            // Gelirler
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GELİRLER',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    const SizedBox(height: 10),
                    _buildEconomyRow('Stadyum Geliri', stadiumRevenue),
                    _buildEconomyRow('Sponsor Geliri', sponsorRevenue),
                    _buildEconomyRow('Maç Bonusu (Kazanma)', matchBonus),
                    const Divider(height: 12),
                    _buildEconomyRow(
                      'Toplam Gelir',
                      totalRevenue,
                      isBold: true,
                      color: Colors.green,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Giderler
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GİDERLER',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    const SizedBox(height: 10),
                    _buildEconomyRow('Oyuncu Maaşları', playerWages),
                    _buildEconomyRow('Bakım Masrafı', maintenanceCost),
                    const Divider(height: 12),
                    _buildEconomyRow(
                      'Toplam Gider',
                      totalExpense,
                      isBold: true,
                      color: Colors.red,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Net Gelir
            Card(
              color: netIncome > 0 ? Colors.blue.shade50 : Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Net Gelir (Maç Başına)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '$netIncome GP',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: netIncome > 0 ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Kulüp Bilgileri
            Text(
              'Kulüp Bilgileri',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            Card(
              child: ListTile(
                title: const Text('Stadyum Kapasitesi'),
                trailing: Text('${club.stadiumCapacity} kişi'),
              ),
            ),
            const SizedBox(height: 8),

            Card(
              child: ListTile(
                title: const Text('Bilet Fiyatı'),
                trailing: Text('${club.ticketPrice} GP'),
              ),
            ),
            const SizedBox(height: 8),

            Card(
              child: ListTile(
                title: const Text('Tesis Seviyesi'),
                trailing: Text('Level ${club.trainingFacilityLevel}'),
              ),
            ),
            const SizedBox(height: 8),

            Card(
              child: ListTile(
                title: const Text('Sponsor Seviyesi'),
                trailing: Text('Level ${club.sponsorLevel}'),
              ),
            ),
            const SizedBox(height: 20),

            // Aksiyonlar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SponsorUpgradeScreen()),
                ),
                icon: const Icon(Icons.trending_up),
                label: const Text('Sponsorluğu Yükselt'),
              ),
            ),
            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DevelopmentScreen()),
                ),
                icon: const Icon(Icons.upgrade),
                label: const Text('Kulüp Geliştirme'),
              ),
            ),
            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TransferHistoryScreen()),
                ),
                icon: const Icon(Icons.history),
                label: const Text('Transfer Geçmişi'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FinancialTransactionsScreen()),
                ),
                icon: const Icon(Icons.list_alt),
                label: const Text('Bütçe Hareketleri'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEconomyRow(String label, int value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
        Text(
          '$value GP',
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }
}
