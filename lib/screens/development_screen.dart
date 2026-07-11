import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../services/ad_service.dart';
import '../widgets/timed_progress_bar.dart';

class DevelopmentScreen extends StatelessWidget {
  const DevelopmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final club = provider.activeClub;

    if (provider.isLoading || club == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isUpgrading = club.isDevelopmentUpgrading;
    final upgradingLabel = switch (club.developmentUpgradeType) {
      'stadium' => 'development.upgradeStadium'.tr(),
      'facility' => 'development.upgradeFacility'.tr(),
      _ => 'development.upgradeTicketPrice'.tr(),
    };
    final stadiumMaxed = club.stadiumCapacity >= 100000;
    final facilityMaxed = club.trainingFacilityLevel >= 10;
    final ticketMaxed = club.ticketPriceLevel >= 10;
    final upgradingDurationDays = switch (club.developmentUpgradeType) {
      'stadium' => (1 + ((club.stadiumCapacity - 15000) ~/ 10000)).clamp(1, 14),
      'facility' => 2 * club.trainingFacilityLevel - 1,
      _ => 2 * club.ticketPriceLevel - 1,
    };

    Future<void> startUpgrade(String upgradeType, int targetValue, String startedMessage) async {
      try {
        await context.read<GameProvider>().startClubDevelopment(
              upgradeType: upgradeType,
              targetValue: targetValue,
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(startedMessage), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text('finance.clubDevelopmentButton'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isUpgrading) ...[
              Card(
                color: Colors.amber.withValues(alpha: 0.12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('development.constructionOngoing'.tr(namedArgs: {'label': upgradingLabel}), style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      TimedProgressBar(
                        completesAt: club.developmentCompletesAt!,
                        totalDuration: Duration(days: upgradingDurationDays),
                        adUsesRemaining: 2 - club.developmentAdUses,
                        onWatchAd: () async {
                          final earned = await AdService.instance.showRewardedAd();
                          if (earned) {
                            await context.read<GameProvider>().reduceClubDevelopmentTimeWithAd();
                          }
                          return earned;
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'development.progressesOffline'.tr(),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              child: ListTile(
                title: Text('finance.stadiumCapacity'.tr()),
                subtitle: Text(stadiumMaxed ? 'development.valueMax'.tr(namedArgs: {'value': club.stadiumCapacity.toString()}) : '${club.stadiumCapacity}'),
                trailing: Builder(builder: (ctx) {
                  if (stadiumMaxed) {
                    return Chip(label: Text('development.maxChip'.tr()));
                  }
                  const increment = 2500;
                  final newCapacity = club.stadiumCapacity + increment;
                  final cost = (increment * 15) + (club.stadiumCapacity * increment) ~/ 50000;
                  final durationDays = (1 + ((club.stadiumCapacity - 15000) ~/ 10000)).clamp(1, 14);
                  return ElevatedButton(
                    onPressed: provider.isBusy || isUpgrading
                        ? null
                        : () => startUpgrade('stadium', newCapacity, 'development.stadiumUpgradeStarted'.tr()),
                    child: Text('development.startButton'.tr(namedArgs: {'cost': cost.toString(), 'days': durationDays.toString()})),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: Text('finance.facilityLevel'.tr()),
                subtitle: Text(facilityMaxed ? 'development.valueMax'.tr(namedArgs: {'value': club.trainingFacilityLevel.toString()}) : '${club.trainingFacilityLevel}'),
                trailing: Builder(builder: (ctx) {
                  if (facilityMaxed) {
                    return Chip(label: Text('development.maxChip'.tr()));
                  }
                  final newLevel = club.trainingFacilityLevel + 1;
                  final cost = newLevel * 15000;
                  final durationDays = 2 * club.trainingFacilityLevel - 1;
                  return ElevatedButton(
                    onPressed: provider.isBusy || isUpgrading
                        ? null
                        : () => startUpgrade('facility', newLevel, 'development.facilityUpgradeStarted'.tr()),
                    child: Text('development.startButton'.tr(namedArgs: {'cost': cost.toString(), 'days': durationDays.toString()})),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: Text('finance.ticketPrice'.tr()),
                subtitle: Text(ticketMaxed
                    ? 'development.ticketPriceMax'.tr(namedArgs: {'price': club.ticketPrice.toString()})
                    : 'development.ticketPriceLeveled'.tr(namedArgs: {'price': club.ticketPrice.toString(), 'level': club.ticketPriceLevel.toString()})),
                trailing: Builder(builder: (ctx) {
                  if (ticketMaxed) {
                    return Chip(label: Text('development.maxChip'.tr()));
                  }
                  final newLevel = club.ticketPriceLevel + 1;
                  final newPrice = 20 + (newLevel - 1) * 8;
                  final cost = newLevel * 6000;
                  final durationDays = 2 * club.ticketPriceLevel - 1;
                  return ElevatedButton(
                    onPressed: provider.isBusy || isUpgrading
                        ? null
                        : () => startUpgrade('ticket_price', newLevel, 'development.ticketPriceUpgradeStarted'.tr(namedArgs: {'price': newPrice.toString()})),
                    child: Text('development.startButton'.tr(namedArgs: {'cost': cost.toString(), 'days': durationDays.toString()})),
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),
            Text('development.budgetLabel'.tr(namedArgs: {'amount': club.budget.toString()}), style: Theme.of(context).textTheme.headlineSmall),
            if (provider.isBusy) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}
