import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/club_info.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import 'setup_club_screen.dart';

/// Lists every league (club) the current user owns (up to 4) and lets them
/// switch between them, or start/join a new one. Reachable both right
/// after login (when the user has clubs already) and from the main menu
/// while already inside a league.
class LeagueSelectorScreen extends StatefulWidget {
  const LeagueSelectorScreen({super.key});

  @override
  State<LeagueSelectorScreen> createState() => _LeagueSelectorScreenState();
}

class _LeagueSelectorScreenState extends State<LeagueSelectorScreen> {
  bool _isSwitching = false;

  Future<void> _switchTo(ClubInfo club) async {
    setState(() => _isSwitching = true);
    try {
      await context.read<GameProvider>().switchActiveClub(club.id);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/root');
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSwitching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Future<void> _addLeague() async {
    final joined = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SetupClubScreen()),
    );
    if (joined == true && mounted) {
      Navigator.of(context).pushReplacementNamed('/root');
    }
  }

  @override
  Widget build(BuildContext context) {
    final myClubs = context.watch<GameProvider>().myClubs;
    final activeClub = context.watch<GameProvider>().activeClub;
    final atMax = myClubs.length >= 4;

    return Scaffold(
      appBar: AppBar(title: Text('leagueSelector.title'.tr())),
      body: _isSwitching
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('leagueSelector.subtitle'.tr(), style: const TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 16),
                for (final club in myClubs)
                  _LeagueCard(
                    club: club,
                    isActive: club.id == activeClub?.id,
                    onTap: () => _switchTo(club),
                  ),
                const SizedBox(height: 16),
                if (atMax)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'leagueSelector.maxReached'.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _addLeague,
                    icon: const Icon(Icons.add),
                    label: Text('leagueSelector.addLeague'.tr()),
                  ),
              ],
            ),
    );
  }
}

class _LeagueCard extends StatelessWidget {
  const _LeagueCard({required this.club, required this.isActive, required this.onTap});

  final ClubInfo club;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: isActive
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.gold, width: 1.5),
            )
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.shield, color: AppColors.gold),
              const SizedBox(width: 12),
              Expanded(
                child: Text(club.name, style: Theme.of(context).textTheme.titleMedium),
              ),
              if (isActive)
                const Icon(Icons.check_circle, color: AppColors.green)
              else
                Text('leagueSelector.switchAction'.tr(), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
