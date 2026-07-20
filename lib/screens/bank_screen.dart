import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bank.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/themed_button.dart';

class BankScreen extends StatefulWidget {
  const BankScreen({super.key});

  @override
  State<BankScreen> createState() => _BankScreenState();
}

class _BankScreenState extends State<BankScreen> {
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GameProvider>().loadBankData();
    });
  }

  Future<void> _showDepositDialog(Bank bank) async {
    final controller = TextEditingController();
    final amount = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(bank.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('bank.limitsLabel'.tr(namedArgs: {
              'min': bank.minDeposit.toString(),
              'max': bank.maxDeposit.toString(),
            })),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'bank.depositAmountLabel'.tr()),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              Navigator.of(dialogContext).pop(value);
            },
            child: Text('bank.depositAction'.tr()),
          ),
        ],
      ),
    );

    if (amount == null || amount <= 0 || !mounted) return;
    setState(() => _isBusy = true);
    try {
      await context.read<GameProvider>().depositToBank(bankId: bank.id, amount: amount);
      if (!mounted) return;
      AppSnackBar.showSuccess(context, 'bank.depositSuccess'.tr());
    } catch (error) {
      if (!mounted) return;
      AppSnackBar.showErrorFromException(context, error);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _withdraw(String depositId) async {
    setState(() => _isBusy = true);
    try {
      await context.read<GameProvider>().withdrawFromBank(depositId: depositId);
      if (!mounted) return;
      AppSnackBar.showSuccess(context, 'bank.withdrawSuccess'.tr());
    } catch (error) {
      if (!mounted) return;
      AppSnackBar.showErrorFromException(context, error);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final banks = provider.banks;
    final deposits = provider.bankDeposits;
    final banksById = {for (final b in banks) b.id: b};

    return Scaffold(
      appBar: AppBar(title: Text('bank.title'.tr())),
      body: (provider.isLoadingBanks || _isBusy)
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (deposits.isNotEmpty) ...[
                  Text('bank.myDepositsTitle'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  for (final deposit in deposits)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(banksById[deposit.bankId]?.name ?? deposit.bankId),
                        subtitle: Text(
                          deposit.isLocked
                              ? 'bank.lockedUntilLabel'.tr(namedArgs: {'date': _formatDate(deposit.unlocksAt)})
                              : 'bank.unlockedLabel'.tr(),
                          style: TextStyle(color: deposit.isLocked ? AppColors.textMuted : AppColors.green),
                        ),
                        trailing: deposit.isLocked
                            ? Text('${deposit.balance} GP', style: const TextStyle(fontWeight: FontWeight.bold))
                            : TextButton(
                                onPressed: () => _withdraw(deposit.id),
                                child: Text('bank.withdrawAction'.tr(namedArgs: {'amount': deposit.balance.toString()})),
                              ),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
                Text('bank.availableBanksTitle'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                for (final bank in banks)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(bank.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 6),
                          Text('bank.dailyRateLabel'.tr(namedArgs: {'rate': bank.dailyRatePercentLabel})),
                          Text(
                            bank.lockUpDays == 0 ? 'bank.noLockUp'.tr() : 'bank.lockUpDaysLabel'.tr(namedArgs: {'days': bank.lockUpDays.toString()}),
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                          Text(
                            'bank.limitsLabel'.tr(namedArgs: {'min': bank.minDeposit.toString(), 'max': bank.maxDeposit.toString()}),
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          GoldButton(
                            onPressed: () => _showDepositDialog(bank),
                            label: 'bank.depositAction'.tr(),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
