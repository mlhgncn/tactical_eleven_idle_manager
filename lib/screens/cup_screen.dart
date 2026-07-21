import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cup_match.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';

/// Shows every cup match involving any of the caller's clubs, across all
/// tournaments (past and the currently active one), grouped by round.
class CupScreen extends StatefulWidget {
  const CupScreen({super.key});

  @override
  State<CupScreen> createState() => _CupScreenState();
}

class _CupScreenState extends State<CupScreen> {
  bool _loading = true;
  String? _error;
  List<CupMatch> _matches = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _matches = await context.read<GameProvider>().loadMyCupMatches();
    } catch (e) {
      _matches = [];
      _error = 'cup.loadFailed'.tr(namedArgs: {'error': e.toString().replaceAll('Exception: ', '')});
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final myClubIds = context.read<GameProvider>().myClubs.map((c) => c.id).toSet();
    final activeClubId = context.read<GameProvider>().activeClub?.id;

    final grouped = <int, List<CupMatch>>{};
    for (final match in _matches) {
      grouped.putIfAbsent(match.cupRound, () => []).add(match);
    }
    final rounds = grouped.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: Text('cup.title'.tr())),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(child: Text(_error!, style: const TextStyle(color: AppColors.red), textAlign: TextAlign.center)),
                    )
                  else if (_matches.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Column(
                        children: [
                          Icon(Icons.emoji_events_outlined, size: 44, color: AppColors.textMuted.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          Text('cup.empty'.tr(), style: const TextStyle(color: AppColors.textMuted), textAlign: TextAlign.center),
                        ],
                      ),
                    )
                  else
                    for (final round in rounds) ...[
                      Text(
                        _roundLabel(round),
                        style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1),
                      ),
                      const SizedBox(height: 8),
                      for (final match in grouped[round]!)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CupMatchCard(
                            match: match,
                            isMineHome: myClubIds.contains(match.homeClubId),
                            isMineAway: myClubIds.contains(match.awayClubId),
                            isActiveClubMatch: match.homeClubId == activeClubId || match.awayClubId == activeClubId,
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
      ),
    );
  }

  String _roundLabel(int round) {
    switch (round) {
      case 1:
        return 'cup.roundOf16'.tr();
      case 2:
        return 'cup.quarterFinal'.tr();
      case 3:
        return 'cup.semiFinal'.tr();
      case 4:
        return 'cup.final'.tr();
      default:
        return 'cup.roundN'.tr(namedArgs: {'n': round.toString()});
    }
  }
}

class _CupMatchCard extends StatelessWidget {
  const _CupMatchCard({required this.match, required this.isMineHome, required this.isMineAway, required this.isActiveClubMatch});

  final CupMatch match;
  final bool isMineHome;
  final bool isMineAway;
  final bool isActiveClubMatch;

  @override
  Widget build(BuildContext context) {
    final myWon = match.isPlayed &&
        ((isMineHome && match.homeScore! > match.awayScore!) || (isMineAway && match.awayScore! > match.homeScore!));
    final isEliminated = match.tournamentStatus == 'completed' && match.isPlayed && (isMineHome || isMineAway) && !myWon;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardTop,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isActiveClubMatch ? AppColors.gold.withValues(alpha: 0.5) : AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              match.homeClubName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w600, color: isMineHome ? AppColors.goldLight : AppColors.textPrimary),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              match.isPlayed ? '${match.homeScore} - ${match.awayScore}' : 'matchDetail.vsLabel'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              match.awayClubName,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w600, color: isMineAway ? AppColors.goldLight : AppColors.textPrimary),
            ),
          ),
          if (isEliminated) ...[
            const SizedBox(width: 8),
            const Icon(Icons.close, color: AppColors.red, size: 16),
          ],
        ],
      ),
    );
  }
}
