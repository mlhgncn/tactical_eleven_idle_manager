import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/player_fm.dart';
import '../models/tactics.dart';
import '../providers/game_provider.dart';
import '../services/ad_service.dart';
import '../theme/app_assets.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/timed_progress_bar.dart';
import 'player_detail_screen.dart';

class _FormationSlot {
  const _FormationSlot(this.group, this.x, this.y);
  final String group;
  final double x;
  final double y;
}

const Map<Formation, List<_FormationSlot>> _formationSlots = {
  Formation.f433: [
    _FormationSlot('GK', 0.5, 0.90),
    _FormationSlot('DEF', 0.14, 0.68),
    _FormationSlot('DEF', 0.38, 0.71),
    _FormationSlot('DEF', 0.62, 0.71),
    _FormationSlot('DEF', 0.86, 0.68),
    _FormationSlot('MID', 0.26, 0.44),
    _FormationSlot('MID', 0.50, 0.40),
    _FormationSlot('MID', 0.74, 0.44),
    _FormationSlot('FOR', 0.20, 0.15),
    _FormationSlot('FOR', 0.50, 0.11),
    _FormationSlot('FOR', 0.80, 0.15),
  ],
  Formation.f442: [
    _FormationSlot('GK', 0.5, 0.90),
    _FormationSlot('DEF', 0.14, 0.68),
    _FormationSlot('DEF', 0.38, 0.71),
    _FormationSlot('DEF', 0.62, 0.71),
    _FormationSlot('DEF', 0.86, 0.68),
    _FormationSlot('MID', 0.14, 0.42),
    _FormationSlot('MID', 0.38, 0.39),
    _FormationSlot('MID', 0.62, 0.39),
    _FormationSlot('MID', 0.86, 0.42),
    _FormationSlot('FOR', 0.38, 0.14),
    _FormationSlot('FOR', 0.62, 0.14),
  ],
  Formation.f352: [
    _FormationSlot('GK', 0.5, 0.90),
    _FormationSlot('DEF', 0.25, 0.72),
    _FormationSlot('DEF', 0.50, 0.75),
    _FormationSlot('DEF', 0.75, 0.72),
    _FormationSlot('MID', 0.10, 0.44),
    _FormationSlot('MID', 0.32, 0.40),
    _FormationSlot('MID', 0.50, 0.36),
    _FormationSlot('MID', 0.68, 0.40),
    _FormationSlot('MID', 0.90, 0.44),
    _FormationSlot('FOR', 0.38, 0.14),
    _FormationSlot('FOR', 0.62, 0.14),
  ],
  Formation.f532: [
    _FormationSlot('GK', 0.5, 0.90),
    _FormationSlot('DEF', 0.08, 0.64),
    _FormationSlot('DEF', 0.28, 0.72),
    _FormationSlot('DEF', 0.50, 0.75),
    _FormationSlot('DEF', 0.72, 0.72),
    _FormationSlot('DEF', 0.92, 0.64),
    _FormationSlot('MID', 0.28, 0.42),
    _FormationSlot('MID', 0.50, 0.39),
    _FormationSlot('MID', 0.72, 0.42),
    _FormationSlot('FOR', 0.38, 0.14),
    _FormationSlot('FOR', 0.62, 0.14),
  ],
  // 4-4-2 "diamond" variant - same GK/DEF/MID/FOR group counts as f442
  // (so it stays interchangeable with saved lineups from that formation),
  // just a narrower diamond midfield instead of a flat bank of four.
  Formation.f442b: [
    _FormationSlot('GK', 0.5, 0.90),
    _FormationSlot('DEF', 0.14, 0.68),
    _FormationSlot('DEF', 0.38, 0.71),
    _FormationSlot('DEF', 0.62, 0.71),
    _FormationSlot('DEF', 0.86, 0.68),
    _FormationSlot('MID', 0.50, 0.52),
    _FormationSlot('MID', 0.22, 0.40),
    _FormationSlot('MID', 0.78, 0.40),
    _FormationSlot('MID', 0.50, 0.28),
    _FormationSlot('FOR', 0.38, 0.14),
    _FormationSlot('FOR', 0.62, 0.14),
  ],
  Formation.f4231: [
    _FormationSlot('GK', 0.5, 0.90),
    _FormationSlot('DEF', 0.14, 0.68),
    _FormationSlot('DEF', 0.38, 0.71),
    _FormationSlot('DEF', 0.62, 0.71),
    _FormationSlot('DEF', 0.86, 0.68),
    _FormationSlot('MID', 0.35, 0.50),
    _FormationSlot('MID', 0.65, 0.50),
    _FormationSlot('MID', 0.18, 0.30),
    _FormationSlot('MID', 0.50, 0.26),
    _FormationSlot('MID', 0.82, 0.30),
    _FormationSlot('FOR', 0.50, 0.12),
  ],
  Formation.f4141: [
    _FormationSlot('GK', 0.5, 0.90),
    _FormationSlot('DEF', 0.14, 0.68),
    _FormationSlot('DEF', 0.38, 0.71),
    _FormationSlot('DEF', 0.62, 0.71),
    _FormationSlot('DEF', 0.86, 0.68),
    _FormationSlot('MID', 0.50, 0.54),
    _FormationSlot('MID', 0.14, 0.36),
    _FormationSlot('MID', 0.38, 0.32),
    _FormationSlot('MID', 0.62, 0.32),
    _FormationSlot('MID', 0.86, 0.36),
    _FormationSlot('FOR', 0.50, 0.12),
  ],
};

/// Greedily fills each formation slot with the highest-rated available
/// player whose position group matches, falling back to the best remaining
/// player of any group if a formation needs more of a group than the squad
/// has. Injured/suspended players are excluded so they fall to the bench.
List<PlayerFM?> _pickStartingXI(List<PlayerFM> squad, List<_FormationSlot> slots) {
  final available = squad.where((p) => !p.hasActiveInjury).toList()
    ..sort((a, b) => b.currentAbility.compareTo(a.currentAbility));
  final used = <String>{};
  final result = <PlayerFM?>[];
  for (final slot in slots) {
    PlayerFM? pick;
    for (final p in available) {
      if (used.contains(p.id)) continue;
      if (p.positionGroup == slot.group) {
        pick = p;
        break;
      }
    }
    if (pick == null) {
      for (final p in available) {
        if (!used.contains(p.id)) {
          pick = p;
          break;
        }
      }
    }
    if (pick != null) used.add(pick.id);
    result.add(pick);
  }
  return result;
}

/// Uses the saved manual lineup (one player id per slot, in slot order) if
/// it's still valid for the current squad/formation - resolves to real,
/// currently-fit players with no duplicates and the right slot count.
/// Falls back to the auto-picked best XI otherwise (new squad, formation
/// just changed, a manually-placed player got transferred/injured, etc.).
List<PlayerFM?> _resolveStartingXI(List<PlayerFM> squad, List<_FormationSlot> slots, Tactics? tactics) {
  final manual = tactics?.startingElevenIds;
  if (manual != null && manual.length == slots.length) {
    final byId = {for (final p in squad) p.id: p};
    final resolved = manual.map((id) => byId[id]).toList();
    final allValid = resolved.every((p) => p != null && !p.hasActiveInjury);
    final uniqueCount = resolved.whereType<PlayerFM>().map((p) => p.id).toSet().length;
    if (allValid && uniqueCount == resolved.length) {
      return resolved;
    }
  }
  return _pickStartingXI(squad, slots);
}

String _initialsOf(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) return words.first.substring(0, words.first.length.clamp(0, 2)).toUpperCase();
  return (words[0][0] + words[1][0]).toUpperCase();
}

String _firstNameOf(String name) => name.trim().split(RegExp(r'\s+')).first;

const _positionGroupOrder = ['GK', 'DEF', 'MID', 'FOR'];
const _positionMismatchPenalties = [0.0, 0.15, 0.30, 0.50];

/// A player's contribution when placed in [slotGroup] (GK/DEF/MID/FOR),
/// scaled down the further [slotGroup] is from the player's own position
/// group - full ability in their own group, increasingly weaker the more
/// out-of-position they are (e.g. a DEF playing FOR is 2 groups away).
int effectiveAbilityInSlot(PlayerFM player, String slotGroup) {
  final ownIndex = _positionGroupOrder.indexOf(player.positionGroup);
  final slotIndex = _positionGroupOrder.indexOf(slotGroup);
  if (ownIndex < 0 || slotIndex < 0) return player.currentAbility;
  final distance = (ownIndex - slotIndex).abs().clamp(0, _positionMismatchPenalties.length - 1);
  final penalty = _positionMismatchPenalties[distance];
  return (player.currentAbility * (1 - penalty)).round();
}

class SquadScreen extends StatelessWidget {
  const SquadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final squad = provider.squadPlayers;
    final tactics = provider.tactics;

    if (provider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (squad.isEmpty) {
      return Scaffold(body: Center(child: Text('squad.loadFailed'.tr())));
    }

    final formation = tactics?.formation ?? Formation.f442;
    final slots = _formationSlots[formation]!;
    final starters = _resolveStartingXI(squad, slots, tactics);
    final startingIds = starters.whereType<PlayerFM>().map((p) => p.id).toSet();
    final bench = squad.where((p) => !startingIds.contains(p.id)).toList()
      ..sort((a, b) => b.currentAbility.compareTo(a.currentAbility));

    final ratedStarters = starters.whereType<PlayerFM>().toList();
    final effectiveAbilities = <String, int>{
      for (var i = 0; i < slots.length; i++)
        if (starters[i] != null) starters[i]!.id: effectiveAbilityInSlot(starters[i]!, slots[i].group),
    };
    final avgPower = ratedStarters.isEmpty
        ? 0
        : (ratedStarters.map((p) => effectiveAbilities[p.id]!).reduce((a, b) => a + b) / ratedStarters.length).round();
    final topRatedId = ratedStarters.isEmpty
        ? null
        : ratedStarters.reduce((a, b) => effectiveAbilities[a.id]! >= effectiveAbilities[b.id]! ? a : b).id;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('squad.title'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
            Text('squad.avgPowerSubtitle'.tr(namedArgs: {'power': avgPower.toString()}), style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'squad.resetLineup'.tr(),
            icon: const Icon(Icons.refresh),
            onPressed: () => _resetLineup(context, provider, squad, slots),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _FormationPill(
              formation: formation,
              onSelected: (value) => _changeFormation(context, provider, value),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.refreshGameState(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AspectRatio(
              aspectRatio: 0.78,
              child: _Pitch(
                slots: slots,
                starters: starters,
                topRatedId: topRatedId,
                captainId: tactics?.captainId,
                onTapPlayer: (player) => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PlayerDetailScreen(player: player)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('squad.benchSectionTitle'.tr(),
                    style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                GestureDetector(
                  onTap: () => _showFullBench(context, provider, starters, bench),
                  child: Text('squad.seeAllBench'.tr(), style: const TextStyle(color: AppColors.goldLight, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 92,
              child: bench.isEmpty
                  ? Center(child: Text('squad.noBenchPlayers'.tr(), style: const TextStyle(color: AppColors.textMuted)))
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: bench.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) => _BenchToken(
                        player: bench[index],
                        onTap: () => _swapIntoLineup(context, provider, starters, bench[index]),
                      ),
                    ),
            ),
            if (squad.any((p) => p.isDeveloping)) ...[
              const SizedBox(height: 24),
              Text('squad.developmentInProgress'.tr(),
                  style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
              const SizedBox(height: 12),
              ...squad.where((p) => p.isDeveloping).map((player) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PlayerDetailScreen(player: player)),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.cardTop, AppColors.cardBottom]),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: TimedProgressBar(
                          completesAt: player.developmentCompletesAt!,
                          totalDuration: const Duration(hours: 2),
                          label: '${player.name} · ${player.position}',
                          adUsesRemaining: 2 - player.developmentAdUses,
                          onWatchAd: () async {
                            final earned = await AdService.instance.showRewardedAd();
                            if (earned) {
                              await provider.reducePlayerDevelopmentTimeWithAd(playerId: player.id);
                            }
                            return earned;
                          },
                        ),
                      ),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  void _changeFormation(BuildContext context, GameProvider provider, Formation newFormation) {
    final current = provider.tactics;
    if (current == null) return;
    final updated = Tactics(
      clubId: current.clubId,
      formation: newFormation,
      mentality: current.mentality,
      captainId: current.captainId,
      penaltyTakerId: current.penaltyTakerId,
      freeKickTakerId: current.freeKickTakerId,
      cornerTakerId: current.cornerTakerId,
      pressIntensity: current.pressIntensity,
      tempo: current.tempo,
      defensiveLine: current.defensiveLine,
      offsideTrap: current.offsideTrap,
      timeWasting: current.timeWasting,
    );
    provider.saveTactics(updated).catchError((error) {
      if (context.mounted) {
        AppSnackBar.showError(context, 'squad.formationSaveFailed'.tr(namedArgs: {'error': error.toString()}));
      }
    });
  }

  void _showFullBench(BuildContext context, GameProvider provider, List<PlayerFM?> starters, List<PlayerFM> bench) {
    String? selectedGroup;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardTop,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _BenchSheetContent(
              bench: bench,
              starters: starters,
              onGroupChanged: (group) => setSheetState(() => selectedGroup = group),
              selectedGroup: selectedGroup,
              onSwap: (player) {
                Navigator.pop(context);
                _swapIntoLineup(context, provider, starters, player);
              },
              onOpenDetail: (player) {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerDetailScreen(player: player)));
              },
            );
          },
        );
      },
    );
  }

  void _swapIntoLineup(BuildContext context, GameProvider provider, List<PlayerFM?> starters, PlayerFM benchPlayer) {
    if (benchPlayer.hasActiveInjury) {
      AppSnackBar.show(context, 'squad.cannotAddToLineup'.tr(namedArgs: {'name': benchPlayer.name, 'reason': benchPlayer.injuryDisplayLabel}));
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardTop,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('squad.replaceWhoQuestion'.tr(namedArgs: {'name': _firstNameOf(benchPlayer.name)}),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: starters.length,
                    separatorBuilder: (_, __) => const Divider(color: AppColors.cardBorder, height: 1),
                    itemBuilder: (context, index) {
                      final starter = starters[index];
                      if (starter == null) return const SizedBox.shrink();
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.cardBottom,
                          child: Text(_initialsOf(starter.name), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(starter.name),
                        subtitle: Text('${starter.position} · ${starter.currentAbility}', style: const TextStyle(color: AppColors.textMuted)),
                        onTap: () {
                          Navigator.pop(context);
                          final newLineup = List<PlayerFM?>.from(starters);
                          newLineup[index] = benchPlayer;
                          _saveLineup(context, provider, newLineup);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// "Sıfırla" - discards any manually set lineup and re-picks the best
  /// available XI for the current formation, purely by current_ability per
  /// slot (same greedy algorithm _resolveStartingXI already falls back to
  /// automatically - this just lets the user trigger it on demand).
  void _resetLineup(BuildContext context, GameProvider provider, List<PlayerFM> squad, List<_FormationSlot> slots) {
    final autoPicked = _pickStartingXI(squad, slots);
    _saveLineup(context, provider, autoPicked);
    AppSnackBar.showSuccess(context, 'squad.lineupReset'.tr());
  }

  void _saveLineup(BuildContext context, GameProvider provider, List<PlayerFM?> newLineup) {
    final current = provider.tactics;
    if (current == null) return;
    final ids = newLineup.map((p) => p?.id).toList();
    if (ids.any((id) => id == null)) return;
    final updated = Tactics(
      clubId: current.clubId,
      formation: current.formation,
      mentality: current.mentality,
      captainId: current.captainId,
      penaltyTakerId: current.penaltyTakerId,
      freeKickTakerId: current.freeKickTakerId,
      cornerTakerId: current.cornerTakerId,
      pressIntensity: current.pressIntensity,
      tempo: current.tempo,
      defensiveLine: current.defensiveLine,
      offsideTrap: current.offsideTrap,
      timeWasting: current.timeWasting,
      startingElevenIds: ids.cast<String>(),
    );
    provider.saveTactics(updated).catchError((error) {
      if (context.mounted) {
        AppSnackBar.showError(context, 'squad.lineupSaveFailed'.tr(namedArgs: {'error': error.toString()}));
      }
    });
  }
}

class _FormationPill extends StatelessWidget {
  const _FormationPill({required this.formation, required this.onSelected});
  final Formation formation;
  final ValueChanged<Formation> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Formation>(
      onSelected: onSelected,
      color: AppColors.cardTop,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppColors.cardBorder)),
      itemBuilder: (context) => Formation.values
          .map((f) => PopupMenuItem(
                value: f,
                child: Text(f.label, style: const TextStyle(color: AppColors.textPrimary)),
              ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.goldLight, AppColors.gold]),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(formation.label, style: const TextStyle(color: AppColors.goldOnGoldText, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: AppColors.goldOnGoldText, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Pitch extends StatelessWidget {
  const _Pitch({
    required this.slots,
    required this.starters,
    required this.topRatedId,
    required this.captainId,
    required this.onTapPlayer,
  });

  final List<_FormationSlot> slots;
  final List<PlayerFM?> starters;
  final String? topRatedId;
  final String? captainId;
  final ValueChanged<PlayerFM> onTapPlayer;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(image: AssetImage(AppAssets.pitchTile), repeat: ImageRepeat.repeat),
          border: Border.fromBorderSide(BorderSide(color: AppColors.cardBorder)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            return Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _PitchMarkingsPainter())),
                for (var i = 0; i < slots.length; i++)
                  if (starters[i] != null)
                    Positioned(
                      left: slots[i].x * width - 28,
                      top: slots[i].y * height - 28,
                      width: 56,
                      height: 72,
                      child: _PlayerToken(
                        player: starters[i]!,
                        slotGroup: slots[i].group,
                        isGoalkeeper: slots[i].group == 'GK',
                        isTopRated: starters[i]!.id == topRatedId,
                        isCaptain: starters[i]!.id == captainId,
                        onTap: () => onTapPlayer(starters[i]!),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PitchMarkingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawLine(Offset(0, size.height * 0.5), Offset(size.width, size.height * 0.5), paint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.5), size.width * 0.16, paint);

    final boxWidth = size.width * 0.56;
    final boxLeft = (size.width - boxWidth) / 2;
    canvas.drawRect(Rect.fromLTWH(boxLeft, 0, boxWidth, size.height * 0.14), paint);
    canvas.drawRect(Rect.fromLTWH(boxLeft, size.height * 0.86, boxWidth, size.height * 0.14), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PlayerToken extends StatelessWidget {
  const _PlayerToken({
    required this.player,
    required this.slotGroup,
    required this.isGoalkeeper,
    required this.isTopRated,
    required this.isCaptain,
    required this.onTap,
  });

  final PlayerFM player;
  final String slotGroup;
  final bool isGoalkeeper;
  final bool isTopRated;
  final bool isCaptain;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isOutOfPosition = player.positionGroup != slotGroup;
    final effectiveAbility = effectiveAbilityInSlot(player, slotGroup);
    final circleColor = isGoalkeeper ? AppColors.green : (isTopRated ? AppColors.gold : AppColors.cardTop);
    final textColor = isGoalkeeper || isTopRated ? AppColors.goldOnGoldText : Colors.white;
    final badgeColor = isOutOfPosition ? AppColors.red : AppColors.gold;
    final badgeTextColor = isOutOfPosition ? Colors.white : AppColors.goldOnGoldText;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: circleColor,
                    border: Border.all(color: isCaptain ? AppColors.blue : Colors.black45, width: isCaptain ? 2.5 : 1.5),
                    boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _initialsOf(player.name),
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Positioned(
                  top: -6,
                  right: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.background, width: 1.5),
                    ),
                    child: Text(
                      '$effectiveAbility',
                      style: TextStyle(color: badgeTextColor, fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                  ),
                ),
                if (isOutOfPosition)
                  Positioned(
                    bottom: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.priority_high, size: 9, color: Colors.white),
                    ),
                  ),
                if (isCaptain)
                  Positioned(
                    bottom: -4,
                    left: -6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: AppColors.blue, shape: BoxShape.circle),
                      child: Text('squad.captainBadge'.tr(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _firstNameOf(player.name),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _BenchToken extends StatelessWidget {
  const _BenchToken({required this.player, required this.onTap});
  final PlayerFM player;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final injured = player.hasActiveInjury;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.cardTop, AppColors.cardBottom]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: injured ? AppColors.red.withValues(alpha: 0.4) : AppColors.cardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: injured ? AppColors.red.withValues(alpha: 0.22) : AppColors.cardBottom,
                border: Border.all(color: injured ? AppColors.red : AppColors.cardBorder),
              ),
              alignment: Alignment.center,
              child: Text(_initialsOf(player.name), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            const SizedBox(height: 6),
            Text(
              _firstNameOf(player.name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
            Text(
              injured ? player.injuryDisplayLabel : '${player.position} · ${player.currentAbility}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: injured ? AppColors.red : AppColors.textMuted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

const _benchPositionGroups = ['GK', 'DEF', 'MID', 'FOR'];

class _BenchSheetContent extends StatelessWidget {
  const _BenchSheetContent({
    required this.bench,
    required this.starters,
    required this.selectedGroup,
    required this.onGroupChanged,
    required this.onSwap,
    required this.onOpenDetail,
  });

  final List<PlayerFM> bench;
  final List<PlayerFM?> starters;
  final String? selectedGroup;
  final ValueChanged<String?> onGroupChanged;
  final ValueChanged<PlayerFM> onSwap;
  final ValueChanged<PlayerFM> onOpenDetail;

  String _groupLabel(String group) => switch (group) {
        'GK' => 'squad.positionGroupGk'.tr(),
        'DEF' => 'squad.positionGroupDef'.tr(),
        'MID' => 'squad.positionGroupMid'.tr(),
        'FOR' => 'squad.positionGroupFor'.tr(),
        _ => group,
      };

  @override
  Widget build(BuildContext context) {
    final filtered = selectedGroup == null ? bench : bench.where((p) => p.positionGroup == selectedGroup).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('squad.benchSheetTitle'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ChoiceChip(
                    label: Text('squad.positionGroupAll'.tr()),
                    selected: selectedGroup == null,
                    onSelected: (_) => onGroupChanged(null),
                  ),
                  const SizedBox(width: 6),
                  for (final group in _benchPositionGroups) ...[
                    ChoiceChip(
                      label: Text(_groupLabel(group)),
                      selected: selectedGroup == group,
                      onSelected: (_) => onGroupChanged(group),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('squad.noBenchPlayers'.tr(), style: const TextStyle(color: AppColors.textMuted))),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(color: AppColors.cardBorder, height: 1),
                      itemBuilder: (context, index) {
                        final player = filtered[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: player.hasActiveInjury ? AppColors.red.withValues(alpha: 0.25) : AppColors.cardBottom,
                            child: Text(_initialsOf(player.name), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(player.name),
                          subtitle: Text(
                            player.hasActiveInjury ? player.injuryDisplayLabel : '${player.position} · ${player.currentAbility}',
                            style: TextStyle(color: player.hasActiveInjury ? AppColors.red : AppColors.textMuted),
                          ),
                          trailing: player.hasActiveInjury
                              ? null
                              : IconButton(
                                  tooltip: 'squad.addToStartingXI'.tr(),
                                  icon: const Icon(Icons.swap_horiz, color: AppColors.goldLight),
                                  onPressed: () => onSwap(player),
                                ),
                          onTap: () => onOpenDetail(player),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
