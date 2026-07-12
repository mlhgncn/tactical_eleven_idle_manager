import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/currency_label.dart';
import '../widgets/themed_button.dart';
import 'bank_screen.dart';
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
      return Scaffold(
        body: Center(child: Text('finance.activeClubNotFound'.tr())),
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
        title: Text('finance.title'.tr()),
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
                    Text(
                      'finance.currentBudget'.tr(),
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 8),
                    CurrencyLabel(
                      amount: club.budget,
                      iconSize: 26,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'finance.reservedBudget'.tr(namedArgs: {'amount': club.blockedBudget.toString()}),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      'finance.availableBudget'.tr(namedArgs: {'amount': (club.budget - club.blockedBudget).toString()}),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Ekonomi Özeti (Maç Başına)
            Text(
              'finance.perMatchEconomyTitle'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            // Gelirler
            Card(
              color: AppColors.green.withValues(alpha: 0.10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: AppColors.green.withValues(alpha: 0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'finance.revenues'.tr(),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.green),
                    ),
                    const SizedBox(height: 10),
                    _buildEconomyRow('finance.stadiumRevenue'.tr(), stadiumRevenue),
                    _buildEconomyRow('finance.sponsorRevenue'.tr(), sponsorRevenue),
                    _buildEconomyRow('finance.matchBonusWin'.tr(), matchBonus),
                    Divider(height: 12, color: AppColors.cardBorder),
                    _buildEconomyRow(
                      'finance.totalRevenue'.tr(),
                      totalRevenue,
                      isBold: true,
                      color: AppColors.green,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Giderler
            Card(
              color: AppColors.red.withValues(alpha: 0.10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: AppColors.red.withValues(alpha: 0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'finance.expenses'.tr(),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.red),
                    ),
                    const SizedBox(height: 10),
                    _buildEconomyRow('finance.playerWages'.tr(), playerWages),
                    _buildEconomyRow('finance.maintenanceCost'.tr(), maintenanceCost),
                    Divider(height: 12, color: AppColors.cardBorder),
                    _buildEconomyRow(
                      'finance.totalExpense'.tr(),
                      totalExpense,
                      isBold: true,
                      color: AppColors.red,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Net Gelir
            Card(
              color: (netIncome > 0 ? AppColors.blue : AppColors.gold).withValues(alpha: 0.10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: (netIncome > 0 ? AppColors.blue : AppColors.gold).withValues(alpha: 0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'finance.netIncomePerMatch'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'finance.amountGp'.tr(namedArgs: {'value': netIncome.toString()}),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: netIncome > 0 ? AppColors.green : AppColors.gold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Kulüp Bilgileri
            Text(
              'finance.clubInfo'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            Card(
              child: ListTile(
                title: Text('finance.stadiumCapacity'.tr()),
                trailing: Text('finance.peopleCount'.tr(namedArgs: {'count': club.stadiumCapacity.toString()})),
              ),
            ),
            const SizedBox(height: 8),

            Card(
              child: ListTile(
                title: Text('finance.ticketPrice'.tr()),
                trailing: Text('finance.amountGp'.tr(namedArgs: {'value': club.ticketPrice.toString()})),
              ),
            ),
            const SizedBox(height: 8),

            Card(
              child: ListTile(
                title: Text('finance.facilityLevel'.tr()),
                trailing: Text('finance.levelValue'.tr(namedArgs: {'level': club.trainingFacilityLevel.toString()})),
              ),
            ),
            const SizedBox(height: 8),

            Card(
              child: ListTile(
                title: Text('finance.sponsorLevel'.tr()),
                trailing: Text('finance.levelValue'.tr(namedArgs: {'level': club.sponsorLevel.toString()})),
              ),
            ),
            const SizedBox(height: 20),

            // Aksiyonlar
            GoldButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SponsorUpgradeScreen()),
              ),
              label: 'finance.upgradeSponsorButton'.tr(),
            ),
            const SizedBox(height: 10),

            GoldButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DevelopmentScreen()),
              ),
              label: 'finance.clubDevelopmentButton'.tr(),
            ),
            const SizedBox(height: 10),

            GoldButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BankScreen()),
              ),
              label: 'finance.bankButton'.tr(),
            ),
            const SizedBox(height: 10),

            GlassButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TransferHistoryScreen()),
              ),
              label: 'finance.transferHistoryButton'.tr(),
            ),
            const SizedBox(height: 10),
            GlassButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FinancialTransactionsScreen()),
              ),
              label: 'finance.budgetTransactionsButton'.tr(),
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
            color: color ?? AppColors.textPrimary,
          ),
        ),
        Text(
          'finance.amountGp'.tr(namedArgs: {'value': value.toString()}),
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
