import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/league_club_option.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snackbar.dart';
import 'market_screen.dart';

class LeagueClubPickerScreen extends StatefulWidget {
  const LeagueClubPickerScreen({super.key, required this.options, this.invitationCode, this.themeCode});

  final List<LeagueClubOption> options;

  /// When this picker was opened via a join-by-code flow, holding the code
  /// lets us re-fetch the (shared, possibly-changed-by-someone-else) list
  /// after a "club just got taken" race so the taken club shows as taken
  /// instead of the user being able to tap the same stale card again.
  final String? invitationCode;

  /// When opened via "create/join a league by theme", preview_league_theme
  /// may have handed back an existing joinable league (shared with other
  /// users) instead of minting a new one - same race as invitationCode, so
  /// this is used the same way to re-fetch after a "club just got taken"
  /// error.
  final String? themeCode;

  @override
  State<LeagueClubPickerScreen> createState() => _LeagueClubPickerScreenState();
}

class _LeagueClubPickerScreenState extends State<LeagueClubPickerScreen> {
  bool _isSelecting = false;
  late List<LeagueClubOption> _options;

  @override
  void initState() {
    super.initState();
    _options = widget.options;
  }

  Future<void> _selectClub(LeagueClubOption option) async {
    if (option.isTaken) return;

    final diamonds = context.read<GameProvider>().diamonds;
    if (option.isPremiumLocked && diamonds < (option.premiumUnlockCost ?? 0)) {
      await _showInsufficientDiamondsDialog(option);
      return;
    }

    final confirmed = await _showConfirmDialog(option);
    if (confirmed != true || !mounted) return;

    setState(() => _isSelecting = true);
    try {
      // Count existing clubs BEFORE switching, so we know whether this is
      // the user's 2nd+ club and should explain the switcher - otherwise
      // the sudden jump to a brand-new, unfamiliar club with an empty feel
      // reads as "my old club got wiped" even though it's untouched.
      final hadOtherClubs = context.read<GameProvider>().myClubs.isNotEmpty;
      await context.read<GameProvider>().selectClubForLeague(option.clubId);
      if (!mounted) return;
      if (hadOtherClubs) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('clubSetup.multiClubInfoTitle'.tr()),
            content: Text('clubSetup.multiClubInfoBody'.tr()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text('clubSetup.multiClubInfoOk'.tr()),
              ),
            ],
          ),
        );
        if (!mounted) return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      // Someone else may have taken this club between when the list was
      // fetched and this tap (two users racing the same shared league,
      // either via invite code or a joinable same-theme league). Re-fetch
      // so the card flips to "taken" instead of staying tappable with
      // stale state.
      final code = widget.invitationCode;
      final theme = widget.themeCode;
      if (code != null || theme != null) {
        try {
          final refreshed = code != null
              ? await context.read<GameProvider>().previewLeagueByCode(code)
              : await context.read<GameProvider>().previewLeagueTheme(theme!);
          if (mounted) setState(() => _options = refreshed);
        } catch (_) {
          // Keep showing the stale list if the refresh itself fails.
        }
      }
      if (!mounted) return;
      setState(() => _isSelecting = false);
      AppSnackBar.showErrorFromException(context, error);
    }
  }

  Future<bool?> _showConfirmDialog(LeagueClubOption option) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(option.clubName),
        content: Text(
          option.isPremiumLocked
              ? 'clubSetup.confirmPremiumBody'.tr(namedArgs: {'cost': option.premiumUnlockCost.toString()})
              : 'clubSetup.confirmFreeBody'.tr(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('clubSetup.confirmAction'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _showInsufficientDiamondsDialog(LeagueClubOption option) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('clubSetup.insufficientDiamondsTitle'.tr()),
        content: Text('clubSetup.insufficientDiamondsBody'.tr(namedArgs: {'cost': option.premiumUnlockCost.toString()})),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MarketScreen()));
            },
            child: Text('clubSetup.goToMarket'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final diamonds = context.watch<GameProvider>().diamonds;
    final premiumOptions = _options.where((o) => o.isPremiumLocked).toList();
    final freeOptions = _options.where((o) => !o.isPremiumLocked).toList()
      ..sort((a, b) => b.quality.compareTo(a.quality));

    return Scaffold(
      appBar: AppBar(title: Text('clubSetup.pickClubTitle'.tr())),
      body: _isSelecting
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    const Icon(Icons.diamond, color: AppColors.blue, size: 20),
                    const SizedBox(width: 8),
                    Text('market.diamondsBalance'.tr(namedArgs: {'count': diamonds.toString()})),
                  ],
                ),
                const SizedBox(height: 16),
                Text('clubSetup.premiumSectionTitle'.tr(), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final option in premiumOptions)
                  _ClubOptionCard(option: option, onTap: () => _selectClub(option)),
                const SizedBox(height: 24),
                Text('clubSetup.freeSectionTitle'.tr(), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final option in freeOptions)
                  _ClubOptionCard(option: option, onTap: () => _selectClub(option)),
              ],
            ),
    );
  }
}

class _ClubOptionCard extends StatelessWidget {
  const _ClubOptionCard({required this.option, required this.onTap});

  final LeagueClubOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: option.isTaken ? 0.45 : 1,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: option.isPremiumLocked
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.gold, width: 1.5),
              )
            : null,
        child: InkWell(
          onTap: option.isTaken ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (option.isPremiumLocked) ...[
                  const Icon(Icons.workspace_premium, color: AppColors.gold),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(option.clubName, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'clubSetup.qualityLabel'.tr(namedArgs: {'quality': option.quality.toString()}),
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (option.isTaken)
                  Chip(
                    label: Text('clubSetup.takenLabel'.tr()),
                    backgroundColor: AppColors.cardTop,
                  )
                else if (option.isPremiumLocked)
                  Chip(
                    label: Text('${option.premiumUnlockCost} 💎'),
                    backgroundColor: AppColors.cardTop,
                    side: const BorderSide(color: AppColors.gold),
                  )
                else
                  Text('clubSetup.freeLabel'.tr(), style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
