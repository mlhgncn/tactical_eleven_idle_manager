import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../services/ad_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/themed_button.dart';
import '../widgets/timed_progress_bar.dart';

/// Club-scoped youth academy: produces one young, low-ability/high-potential
/// player per cycle for free (just facility level + wait time), as an
/// alternative to buying diamond packs or scouting the transfer market.
class AcademyScreen extends StatelessWidget {
  const AcademyScreen({super.key});

  /// Mirrors start_academy_production's wait-time formula so the
  /// progress bar's total duration matches what the server actually
  /// scheduled (the server only persists the completion timestamp, not
  /// the original wait length).
  static Duration _waitDurationFor(int facilityLevel) {
    final hours = (24 - (facilityLevel - 1) * 3).clamp(4, 24);
    return Duration(hours: hours);
  }

  Future<void> _start(BuildContext context) async {
    try {
      await context.read<GameProvider>().startAcademyProduction();
    } catch (error) {
      if (!context.mounted) return;
      AppSnackBar.showErrorFromException(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final club = provider.activeClub;

    return Scaffold(
      appBar: AppBar(title: Text('academy.title'.tr())),
      body: club == null
          ? Center(child: Text('dashboard.clubNotFound'.tr()))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.school, color: AppColors.gold, size: 22),
                            const SizedBox(width: 8),
                            Text('academy.cardTitle'.tr(), style: Theme.of(context).textTheme.titleMedium),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'academy.description'.tr(),
                          style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        if (club.isAcademyProducing) ...[
                          TimedProgressBar(
                            completesAt: club.academyCompletesAt!,
                            totalDuration: _waitDurationFor(club.trainingFacilityLevel),
                            label: 'academy.inProgressLabel'.tr(),
                            adUsesRemaining: 2 - club.academyAdUses,
                            onWatchAd: () async {
                              final earned = await AdService.instance.showRewardedAd();
                              if (earned) {
                                await context.read<GameProvider>().reduceAcademyTimeWithAd();
                              }
                              return earned;
                            },
                          ),
                        ] else ...[
                          Text(
                            'academy.waitTimeLabel'.tr(namedArgs: {
                              'hours': _waitDurationFor(club.trainingFacilityLevel).inHours.toString(),
                            }),
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'academy.facilityHint'.tr(),
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 14),
                          GoldButton(
                            onPressed: () => _start(context),
                            label: 'academy.startAction'.tr(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
