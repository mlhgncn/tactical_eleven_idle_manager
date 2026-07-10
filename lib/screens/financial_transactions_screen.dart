import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../widgets/async_state_builder.dart';

const _typeLabels = {
  'match_income': 'Maç Geliri',
  'upgrade_sponsor': 'Sponsor Yükseltmesi',
  'upgrade_club': 'Kulüp Geliştirme',
  'transfer_revenue': 'Transfer Geliri',
  'transfer_cost': 'Transfer Gideri',
  'offline_income': 'Çevrimdışı Gelir',
  'sign_free_agent': 'Serbest Oyuncu Transferi',
  'ad_reward': 'Reklam Ödülü',
};

class FinancialTransactionsScreen extends StatelessWidget {
  const FinancialTransactionsScreen({super.key});

  String _categoryLabel(String type) {
    return _typeLabels[type] ?? type.split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final items = provider.financialTransactions;
    final isLoading = provider.isLoadingTransactions;
    final errorMessage = provider.transactionsErrorMessage;

    return Scaffold(
      appBar: AppBar(title: const Text('Bütçe Hareketleri')),
      body: AsyncStateBuilder(
        isLoading: isLoading,
        errorMessage: errorMessage,
        isEmpty: items.isEmpty,
        emptyBuilder: () => const Center(child: Text('Henüz bütçe hareketi yok.')),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final tx = items[index];
            return Card(
              child: ListTile(
                title: Text(tx.description),
                subtitle: Text('${_categoryLabel(tx.type)} • ${DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(tx.createdAt.toLocal())}'),
                trailing: Text(
                  '${tx.amount > 0 ? '+' : ''}${tx.amount} GP',
                  style: TextStyle(
                    color: tx.amount > 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
