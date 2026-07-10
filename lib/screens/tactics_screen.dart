import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/match_fixture.dart';
import '../models/player_fm.dart';
import '../models/tactics.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/themed_button.dart';

String _initialsOf(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) return words.first.substring(0, words.first.length.clamp(0, 2)).toUpperCase();
  return (words[0][0] + words[1][0]).toUpperCase();
}

String _firstNameOf(String name) => name.trim().split(RegExp(r'\s+')).first;

class TacticsScreen extends StatefulWidget {
  const TacticsScreen({super.key});

  @override
  State<TacticsScreen> createState() => _TacticsScreenState();
}

class _TacticsScreenState extends State<TacticsScreen> {
  late Tactics _tactics;
  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<GameProvider>();
    final squad = provider.squadPlayers;
    final saved = provider.tactics;

    if (saved != null) {
      _tactics = saved;
      return;
    }

    final defaultPlayer = squad.isNotEmpty ? squad.first.id : '';
    _tactics = Tactics(
      clubId: provider.activeClub?.id ?? 'club',
      captainId: defaultPlayer,
      penaltyTakerId: defaultPlayer,
    );
  }

  Future<void> _saveTactics() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      await context.read<GameProvider>().saveTactics(_tactics);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('tactics.savedSuccess'.tr()), backgroundColor: AppColors.green),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('tactics.saveFailed'.tr(namedArgs: {'error': error.toString()}))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _pickSetPieceTaker(List<PlayerFM> squad, String title, String currentId, ValueChanged<String> onPicked) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardTop,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) {
        final sorted = List<PlayerFM>.from(squad)..sort((a, b) => b.currentAbility.compareTo(a.currentAbility));
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) => const Divider(color: AppColors.cardBorder, height: 1),
                    itemBuilder: (context, index) {
                      final player = sorted[index];
                      final selected = player.id == currentId;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: selected ? AppColors.gold : AppColors.cardBottom,
                          child: Text(_initialsOf(player.name),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: selected ? AppColors.goldOnGoldText : Colors.white)),
                        ),
                        title: Text(player.name),
                        subtitle: Text('${player.position} · ${player.currentAbility}', style: const TextStyle(color: AppColors.textMuted)),
                        trailing: selected ? const Icon(Icons.check_circle, color: AppColors.goldLight) : null,
                        onTap: () {
                          onPicked(player.id);
                          Navigator.pop(context);
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

  String _tierLabel(int value, List<String> labels) {
    if (value < 34) return labels[0];
    if (value < 67) return labels[1];
    return labels[2];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final squad = provider.squadPlayers;

    if (provider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (squad.isEmpty) {
      return Scaffold(body: Center(child: Text('squad.loadFailed'.tr())));
    }

    final nextFixture = provider.fixtures
        .where((f) => f.status != 'Tamamlandı')
        .fold<MatchFixture?>(null, (best, f) {
      if (best == null) return f;
      return f.kickoff.isBefore(best.kickoff) ? f : best;
    });
    final subtitle = nextFixture != null
        ? 'tactics.subtitleWithOpponent'.tr(namedArgs: {'opponent': nextFixture.opponentName})
        : 'tactics.subtitleNoOpponent'.tr();

    PlayerFM playerById(String id) => squad.firstWhere((p) => p.id == id, orElse: () => squad.first);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('navigation.tactics'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _SectionCard(
            title: 'tactics.gameApproach'.tr(),
            child: Row(
              children: [
                for (final mentality in Mentality.values) ...[
                  Expanded(
                    child: _MentalityChip(
                      label: switch (mentality) {
                        Mentality.defensive => 'tactics.mentalityDefensive'.tr(),
                        Mentality.balanced => 'tactics.balanced'.tr(),
                        Mentality.attacking => 'tactics.mentalityAttacking'.tr(),
                      },
                      selected: _tactics.mentality == mentality,
                      onTap: () => setState(() => _tactics.mentality = mentality),
                    ),
                  ),
                  if (mentality != Mentality.attacking) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            child: Column(
              children: [
                _TacticSlider(
                  label: 'tactics.pressIntensity'.tr(),
                  valueLabel: _tierLabel(_tactics.pressIntensity, ['tactics.tierLow'.tr(), 'tactics.tierMid'.tr(), 'tactics.tierHigh'.tr()]),
                  value: _tactics.pressIntensity,
                  onChanged: (v) => setState(() => _tactics.pressIntensity = v),
                ),
                const SizedBox(height: 18),
                _TacticSlider(
                  label: 'tactics.tempo'.tr(),
                  valueLabel: _tierLabel(_tactics.tempo, ['tactics.tierLow'.tr(), 'tactics.tierMid'.tr(), 'tactics.tierHigh'.tr()]),
                  value: _tactics.tempo,
                  onChanged: (v) => setState(() => _tactics.tempo = v),
                ),
                const SizedBox(height: 18),
                _TacticSlider(
                  label: 'tactics.defensiveLine'.tr(),
                  valueLabel: _tierLabel(_tactics.defensiveLine, ['tactics.lineDeep'.tr(), 'tactics.tierMid'.tr(), 'tactics.lineHigh'.tr()]),
                  value: _tactics.defensiveLine,
                  onChanged: (v) => setState(() => _tactics.defensiveLine = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            child: Column(
              children: [
                _ToggleRow(
                  title: 'tactics.offsideTacticTitle'.tr(),
                  subtitle: 'tactics.offsideTacticSubtitle'.tr(),
                  value: _tactics.offsideTrap,
                  onChanged: (v) => setState(() => _tactics.offsideTrap = v),
                ),
                const Divider(color: AppColors.cardBorder, height: 24),
                _ToggleRow(
                  title: 'tactics.timeWastingTitle'.tr(),
                  subtitle: 'tactics.timeWastingSubtitle'.tr(),
                  value: _tactics.timeWasting,
                  onChanged: (v) => setState(() => _tactics.timeWasting = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'tactics.setPiecesTitle'.tr(),
            child: Row(
              children: [
                Expanded(
                  child: _SetPieceSlot(
                    label: 'tactics.freeKickLabel'.tr(),
                    player: playerById(_tactics.freeKickTakerId.isEmpty ? squad.first.id : _tactics.freeKickTakerId),
                    onTap: () => _pickSetPieceTaker(squad, 'tactics.pickFreeKickTaker'.tr(), _tactics.freeKickTakerId,
                        (id) => setState(() => _tactics.freeKickTakerId = id)),
                  ),
                ),
                Expanded(
                  child: _SetPieceSlot(
                    label: 'tactics.cornerLabel'.tr(),
                    player: playerById(_tactics.cornerTakerId.isEmpty ? squad.first.id : _tactics.cornerTakerId),
                    onTap: () => _pickSetPieceTaker(
                        squad, 'tactics.pickCornerTaker'.tr(), _tactics.cornerTakerId, (id) => setState(() => _tactics.cornerTakerId = id)),
                  ),
                ),
                Expanded(
                  child: _SetPieceSlot(
                    label: 'tactics.penaltyLabel'.tr(),
                    player: playerById(_tactics.penaltyTakerId.isEmpty ? squad.first.id : _tactics.penaltyTakerId),
                    onTap: () => _pickSetPieceTaker(
                        squad, 'tactics.pickPenaltyTaker'.tr(), _tactics.penaltyTakerId, (id) => setState(() => _tactics.penaltyTakerId = id)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GoldButton(
            isLoading: _isSaving,
            onPressed: _isSaving ? null : _saveTactics,
            label: 'tactics.saveButton'.tr(),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({this.title, required this.child});
  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.cardTop, AppColors.cardBottom]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

class _MentalityChip extends StatelessWidget {
  const _MentalityChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? null : AppColors.cardBottom,
          gradient: selected ? const LinearGradient(colors: [AppColors.goldLight, AppColors.gold]) : null,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? Colors.transparent : AppColors.cardBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.goldOnGoldText : AppColors.textMuted,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _TacticSlider extends StatelessWidget {
  const _TacticSlider({required this.label, required this.valueLabel, required this.value, required this.onChanged});
  final String label;
  final String valueLabel;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            Text(valueLabel, style: const TextStyle(color: AppColors.goldLight, fontWeight: FontWeight.bold)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.gold,
            inactiveTrackColor: AppColors.cardBorder,
            thumbColor: AppColors.goldLight,
            overlayColor: AppColors.gold.withValues(alpha: 0.2),
            trackHeight: 4,
          ),
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 100,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.title, required this.subtitle, required this.value, required this.onChanged});
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.green),
      ],
    );
  }
}

class _SetPieceSlot extends StatelessWidget {
  const _SetPieceSlot({required this.label, required this.player, required this.onTap});
  final String label;
  final PlayerFM player;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AppColors.goldLight, AppColors.gold])),
            alignment: Alignment.center,
            child: Text(_initialsOf(player.name), style: const TextStyle(color: AppColors.goldOnGoldText, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 6),
          Text(_firstNameOf(player.name), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}
