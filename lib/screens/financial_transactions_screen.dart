import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../widgets/async_state_builder.dart';

Map<String, String> get _typeLabels => {
      'match_income': 'finance.txMatchIncome'.tr(),
      'upgrade_sponsor': 'finance.txUpgradeSponsor'.tr(),
      'upgrade_club': 'finance.clubDevelopmentButton'.tr(),
      'transfer_revenue': 'finance.txTransferRevenue'.tr(),
      'transfer_cost': 'finance.txTransferCost'.tr(),
      'offline_income': 'finance.txOfflineIncome'.tr(),
      'sign_free_agent': 'finance.txSignFreeAgent'.tr(),
      'ad_reward': 'finance.txAdReward'.tr(),
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
      appBar: AppBar(title: Text('finance.budgetTransactionsButton'.tr())),
      body: AsyncStateBuilder(
        isLoading: isLoading,
        errorMessage: errorMessage,
        isEmpty: items.isEmpty,
        emptyBuilder: () => Center(child: Text('finance.noTransactionsYet'.tr())),
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
