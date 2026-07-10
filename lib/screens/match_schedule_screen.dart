import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/match_fixture.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/club_badge.dart';
import 'match_detail_screen.dart';

class MatchScheduleScreen extends StatefulWidget {
  const MatchScheduleScreen({super.key});

  @override
  State<MatchScheduleScreen> createState() => _MatchScheduleScreenState();
}

class _MatchScheduleScreenState extends State<MatchScheduleScreen> {
  Timer? _liveRefreshTimer;

  @override
  void initState() {
    super.initState();
    // Matches now resolve automatically server-side (pg_cron) at kickoff
    // time, whether the user is in the app or not. This periodic refresh
    // is what lets someone who *is* in the app around kickoff time actually
    // see it land - without it they'd only find out on the next manual
    // pull-to-refresh.
    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      context.read<GameProvider>().refreshGameState();
    });
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final fixtures = provider.fixtures;
    final playedFixtures = fixtures.where((f) => f.status == 'Tamamlandı').toList().reversed.toList();

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TabBar(
              labelColor: AppColors.goldLight,
              unselectedLabelColor: AppColors.navInactive,
              indicatorColor: AppColors.goldLight,
              tabs: [
                Tab(text: 'navigation.calendar'.tr()),
                Tab(text: 'matchSchedule.tabResults'.tr()),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                RefreshIndicator(
                  onRefresh: () => context.read<GameProvider>().refreshGameState(),
                  child: fixtures.isEmpty
                    ? ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 80),
                            child: Center(child: Text('matchSchedule.noFixturesYet'.tr())),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: fixtures.length,
                        itemBuilder: (context, index) {
                          final fixture = fixtures[index];
                          final isPlayed = fixture.status == 'Tamamlandı';
                          final homeAwayLabel = fixture.isHome ? 'matchSchedule.homeShort'.tr() : 'matchSchedule.awayShort'.tr();
                          final homeAwayColor = fixture.isHome ? AppColors.green : AppColors.blue;
                          final dateLabel = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR')
                              .format(fixture.kickoff.toLocal());

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: isPlayed
                                  ? () => Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => MatchDetailScreen(fixture: fixture)),
                                      )
                                  : null,
                              child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: ClubBadge(
                                  clubName: fixture.opponentName,
                                  kind: fixture.isHome ? ClubBadgeKind.away : ClubBadgeKind.home,
                                  size: 36,
                                ),
                                title: Text(fixture.opponentName,
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (fixture.opponentUsername != null)
                                      Text('@${fixture.opponentUsername}',
                                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: homeAwayColor.withValues(alpha: 0.16),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: homeAwayColor.withValues(alpha: 0.4)),
                                          ),
                                          child: Text(
                                            homeAwayLabel,
                                            style: TextStyle(
                                              color: homeAwayColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text('matchSchedule.weekLabel'.tr(namedArgs: {'week': fixture.week.toString()}), style: const TextStyle(color: AppColors.textMuted)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      isPlayed
                                          ? '${fixture.homeScore} - ${fixture.awayScore}'
                                          : dateLabel,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: isPlayed ? AppColors.textPrimary : AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Chip(
                                  label: Text(fixture.status),
                                  backgroundColor: fixture.status == 'Tamamlandı'
                                      ? AppColors.green.withValues(alpha: 0.14)
                                      : AppColors.gold.withValues(alpha: 0.14),
                                  labelStyle: TextStyle(
                                    color: fixture.status == 'Tamamlandı' ? AppColors.green : AppColors.goldLight,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                  side: BorderSide.none,
                                ),
                              ),
                              ),
                            ),
                          );
                        },
                      ),
                ),
                RefreshIndicator(
                  onRefresh: () => context.read<GameProvider>().refreshGameState(),
                  child: playedFixtures.isEmpty
                    ? ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 80),
                            child: Center(child: Text('matchSchedule.noPastMatches'.tr())),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: playedFixtures.length,
                        itemBuilder: (context, index) => _ResultCard(fixture: playedFixtures[index]),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.fixture});

  final MatchFixture fixture;

  @override
  Widget build(BuildContext context) {
    final ownScore = fixture.isHome ? fixture.homeScore : fixture.awayScore;
    final opponentScore = fixture.isHome ? fixture.awayScore : fixture.homeScore;
    final Color resultColor;
    final String resultLabel;
    if (ownScore > opponentScore) {
      resultColor = AppColors.green;
      resultLabel = 'matchSchedule.resultWin'.tr();
    } else if (ownScore < opponentScore) {
      resultColor = AppColors.red;
      resultLabel = 'matchSchedule.resultLoss'.tr();
    } else {
      resultColor = AppColors.gold;
      resultLabel = 'matchSchedule.resultDraw'.tr();
    }
    final dateLabel = DateFormat('dd.MM.yyyy', 'tr_TR').format(fixture.kickoff.toLocal());
    final homeAwayLabel = fixture.isHome ? 'matchSchedule.homeFull'.tr() : 'matchSchedule.awayShort'.tr();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MatchDetailScreen(fixture: fixture)),
        ),
        contentPadding: const EdgeInsets.all(16),
        leading: ClubBadge(
          clubName: fixture.opponentName,
          kind: fixture.isHome ? ClubBadgeKind.away : ClubBadgeKind.home,
          size: 36,
        ),
        title: Text(
          '${fixture.isHome ? fixture.homeScore : fixture.awayScore} - ${fixture.isHome ? fixture.awayScore : fixture.homeScore}  ${fixture.opponentName}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (fixture.opponentUsername != null)
              Text('@${fixture.opponentUsername}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
            const SizedBox(height: 8),
            Text('$homeAwayLabel · ${'matchSchedule.weekLabel'.tr(namedArgs: {'week': fixture.week.toString()})} · $dateLabel'),
          ],
        ),
        trailing: Chip(
          label: Text(resultLabel),
          backgroundColor: resultColor.withValues(alpha: 0.14),
          labelStyle: TextStyle(color: resultColor, fontWeight: FontWeight.bold, fontSize: 11),
          side: BorderSide.none,
        ),
      ),
    );
  }
}
