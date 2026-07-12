import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/club_info.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import 'setup_club_screen.dart';

/// Shown once, right after entering the app, when the active club's league
/// season has just completed (club.pendingSeasonEndSeasonId != null).
/// Displays the final standings and asks whether to continue with the same
/// club in a fresh season or leave the league and set up a new one. This
/// screen owns the whole decision - it's pushed as a full-screen route and
/// the user cannot dismiss it without picking one of the two options.
class SeasonEndScreen extends StatefulWidget {
  const SeasonEndScreen({super.key, required this.club});

  final ClubInfo club;

  @override
  State<SeasonEndScreen> createState() => _SeasonEndScreenState();
}

class _SeasonEndScreenState extends State<SeasonEndScreen> {
  List<Map<String, dynamic>>? _standings;
  bool _isLoadingStandings = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadStandings();
  }

  Future<void> _loadStandings() async {
    final seasonId = widget.club.pendingSeasonEndSeasonId;
    if (seasonId == null) return;
    try {
      final standings = await context.read<GameProvider>().loadLeagueStandingsForSeason(seasonId);
      if (!mounted) return;
      setState(() {
        _standings = standings;
        _isLoadingStandings = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingStandings = false);
    }
  }

  bool get _isChampion {
    final standings = _standings;
    if (standings == null || standings.isEmpty) return false;
    final top = standings.first;
    final topClubId = (top['club'] as Map?)?['id'] as String?;
    return topClubId == widget.club.id;
  }

  Future<void> _continue() async {
    setState(() => _isSubmitting = true);
    try {
      await context.read<GameProvider>().continueClubNewSeason(widget.club.id);
      await context.read<GameProvider>().refreshGameState(activeClubId: widget.club.id);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/root');
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Future<void> _leave() async {
    setState(() => _isSubmitting = true);
    try {
      await context.read<GameProvider>().releaseClubAndLeaveLeague(widget.club.id);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => SetupClubScreen()),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text('seasonEnd.title'.tr()),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isChampion) ...[
                  const Icon(Icons.emoji_events, color: AppColors.gold, size: 64),
                  const SizedBox(height: 8),
                  Text(
                    'seasonEnd.championTitle'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.gold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'seasonEnd.championSubtitle'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ] else ...[
                  Text(
                    'seasonEnd.seasonOverTitle'.tr(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
                const SizedBox(height: 20),
                Expanded(
                  child: _isLoadingStandings
                      ? const Center(child: CircularProgressIndicator())
                      : _StandingsList(standings: _standings ?? const [], myClubId: widget.club.id),
                ),
                const SizedBox(height: 16),
                Text('seasonEnd.question'.tr(), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _continue,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, minimumSize: const Size.fromHeight(48)),
                  child: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('seasonEnd.continueButton'.tr()),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _isSubmitting ? null : _leave,
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: Text('seasonEnd.leaveButton'.tr()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StandingsList extends StatelessWidget {
  const _StandingsList({required this.standings, required this.myClubId});

  final List<Map<String, dynamic>> standings;
  final String myClubId;

  @override
  Widget build(BuildContext context) {
    if (standings.isEmpty) {
      return Center(child: Text('seasonEnd.noStandings'.tr(), style: const TextStyle(color: AppColors.textMuted)));
    }
    return ListView.separated(
      itemCount: standings.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final row = standings[index];
        final club = row['club'] as Map?;
        final isMe = club?['id'] == myClubId;
        return Container(
          color: isMe ? AppColors.gold.withValues(alpha: 0.12) : null,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              SizedBox(width: 28, child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold))),
              Expanded(
                child: Text(
                  club?['name']?.toString() ?? '-',
                  style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.normal),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('${row['points'] ?? 0} P', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }
}
