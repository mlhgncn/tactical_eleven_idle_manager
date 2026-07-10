import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/timed_progress_bar.dart';

class SponsorUpgradeScreen extends StatefulWidget {
  const SponsorUpgradeScreen({super.key});

  @override
  State<SponsorUpgradeScreen> createState() => _SponsorUpgradeScreenState();
}

class _SponsorUpgradeScreenState extends State<SponsorUpgradeScreen> {
  bool _isUpgrading = false;
  String? _errorMessage;

  void _handleUpgrade() async {
    final provider = context.read<GameProvider>();

    setState(() {
      _isUpgrading = true;
      _errorMessage = null;
    });

    try {
      await provider.upgradeSponsor();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('sponsor.upgradeStartedSuccess'.tr()),
            backgroundColor: AppColors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        setState(() {
          _errorMessage = msg;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isUpgrading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final club = provider.activeClub;

    if (club == null) {
      return Scaffold(
        appBar: AppBar(title: Text('finance.upgradeSponsorButton'.tr())),
        body: Center(child: Text('finance.activeClubNotFound'.tr())),
      );
    }

    final currentLevel = club.sponsorLevel;
    final maxLevel = 5;
    final isMaxed = currentLevel >= maxLevel;
    final isUpgradingNow = club.isSponsorUpgrading;
    final upgradeCost = 5000 * currentLevel;
    final upgradeDurationDays = 2 * currentLevel - 1;
    final newLevel = currentLevel + 1;
    final newRevenuePerMatch = newLevel * 500;
    final currentRevenuePerMatch = currentLevel * 500;
    final revenueIncrease = newRevenuePerMatch - currentRevenuePerMatch;
    final canAfford = club.budget >= upgradeCost;

    return Scaffold(
      appBar: AppBar(
        title: Text('finance.upgradeSponsorButton'.tr()),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'sponsor.sponsorshipDealTitle'.tr(),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),

            // Mevcut Durum
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('sponsor.currentLevel'.tr()),
                        Text(
                          'finance.levelValue'.tr(namedArgs: {'level': currentLevel.toString()}),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('sponsor.revenuePerMatch'.tr()),
                        Text(
                          'finance.amountGp'.tr(namedArgs: {'value': currentRevenuePerMatch.toString()}),
                          style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: currentLevel / maxLevel,
                        minHeight: 8,
                        backgroundColor: AppColors.cardBottom,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isMaxed ? AppColors.green : AppColors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'sponsor.levelFraction'.tr(namedArgs: {'current': currentLevel.toString(), 'max': maxLevel.toString()}),
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (isUpgradingNow) ...[
              Card(
                color: AppColors.gold.withValues(alpha: 0.10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: AppColors.gold.withValues(alpha: 0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('sponsor.upgradeOngoing'.tr(), style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 12),
                      TimedProgressBar(
                        completesAt: club.sponsorUpgradeCompletesAt!,
                        totalDuration: Duration(days: 2 * currentLevel - 1),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'development.progressesOffline'.tr(),
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (!isMaxed) ...[
              // Yükseltme Bilgisi
              Card(
                color: AppColors.blue.withValues(alpha: 0.10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: AppColors.blue.withValues(alpha: 0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'sponsor.upgradeLevelTitle'.tr(),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('sponsor.newLevel'.tr()),
                          Text(
                            'finance.levelValue'.tr(namedArgs: {'level': newLevel.toString()}),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('sponsor.newMatchRevenue'.tr()),
                          Text(
                            'finance.amountGp'.tr(namedArgs: {'value': newRevenuePerMatch.toString()}),
                            style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.trending_up, color: AppColors.green, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'sponsor.revenueIncreasePerMatch'.tr(namedArgs: {'amount': revenueIncrease.toString()}),
                              style: const TextStyle(
                                color: AppColors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Maliyet
              Card(
                color: AppColors.gold.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: AppColors.gold.withValues(alpha: 0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'sponsor.upgradeCostTitle'.tr(),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('sponsor.requiredBudget'.tr()),
                          Text(
                            'finance.amountGp'.tr(namedArgs: {'value': upgradeCost.toString()}),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.goldLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('sponsor.duration'.tr()),
                          Text(
                            'sponsor.durationDays'.tr(namedArgs: {'days': upgradeDurationDays.toString()}),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.blue),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('finance.currentBudget'.tr()),
                          Text(
                            'finance.amountGp'.tr(namedArgs: {'value': club.budget.toString()}),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: canAfford ? AppColors.green : AppColors.red,
                            ),
                          ),
                        ],
                      ),
                      if (!canAfford) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.red.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning, color: AppColors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'sponsor.insufficientBudget'.tr(),
                                  style: const TextStyle(
                                    color: AppColors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Geri Dönüş Hesaplaması
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'sponsor.roiTitle'.tr(),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'sponsor.roiDescription'.tr(),
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'sponsor.roiMatches'.tr(namedArgs: {'count': (upgradeCost / revenueIncrease).ceil().toString()}),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppColors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Error Message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: AppColors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.red),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Upgrade Butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (canAfford && !_isUpgrading) ? _handleUpgrade : null,
                  icon: _isUpgrading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.goldOnGoldText),
                          ),
                        )
                      : const Icon(Icons.upgrade),
                  label: Text(_isUpgrading ? 'sponsor.startingButton'.tr() : 'sponsor.startUpgradeButton'.tr()),
                ),
              ),
            ] else ...[
              // Maksimum Seviyeye Ulaşıldı
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    const Icon(Icons.star, size: 64, color: AppColors.goldLight),
                    const SizedBox(height: 16),
                    Text(
                      'sponsor.maxLevelReachedTitle'.tr(),
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'sponsor.maxLevelDescription'.tr(namedArgs: {'amount': currentRevenuePerMatch.toString()}),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
