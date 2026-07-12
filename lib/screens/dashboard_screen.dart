import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'dart:async';

import '../models/match_fixture.dart';
import '../providers/game_provider.dart';
import '../theme/app_assets.dart';
import '../theme/app_theme.dart';
import '../widgets/club_badge.dart';
import '../widgets/form_strip.dart';
import '../widgets/themed_button.dart';
import 'market_screen.dart';
import 'match_schedule_screen.dart';
import 'opponent_scout_screen.dart';
import 'squad_screen.dart';
import 'transfer_market_screen.dart';
import 'league_table_screen.dart';

/// The "Maç Gecesi" (Match Night) home dashboard from the design spec:
/// stadium hero, next-match card, form strip, quick actions, mini table.
/// This is the "Kulüp" tab's content - the other tabs (Kadro, Taktik,
/// Transfer, Takvim, Puan Durumu, Gelen) remain their own screens.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final club = provider.activeClub;
    if (club == null) {
      return Center(child: Text('dashboard.clubNotFound'.tr()));
    }

    final nextFixture = provider.fixtures
        .where((f) => f.status != 'Tamamlandı')
        .fold<MatchFixture?>(null, (best, f) {
      if (best == null) return f;
      return f.kickoff.isBefore(best.kickoff) ? f : best;
    });

    final standings = provider.standings;
    final myStanding = standings.firstWhere(
      (row) => (row['club'] as Map?)?['id'] == club.id,
      orElse: () => const {},
    );
    final myPosition = myStanding.isEmpty
        ? null
        : standings.indexOf(myStanding) + 1;

    final recentForm = _recentForm(provider, club.id);
    final leagueName = (provider.seasonState?['league'] as Map?)?['name'] as String? ?? 'dashboard.defaultLeagueName'.tr();
    final pendingOffers = provider.pendingIncomingOfferCount;

    return RefreshIndicator(
      onRefresh: () => context.read<GameProvider>().refreshGameState(),
      child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Hero(club: club, nextFixture: nextFixture, standings: standings, myPosition: myPosition),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: _card(
              child: Row(
                children: [
                  Text('dashboard.formLabel'.tr(), style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
                  const SizedBox(width: 12),
                  Expanded(child: FormStrip(results: recentForm, size: 26)),
                  if (myPosition != null)
                    Column(
                      children: [
                        Text('$myPosition.', style: const TextStyle(color: AppColors.goldLight, fontWeight: FontWeight.bold, fontSize: 22)),
                        Text('dashboard.positionLabel'.tr(), style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5)),
                      ],
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 13, 18, 0),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 11,
              crossAxisSpacing: 11,
              childAspectRatio: 2.6,
              children: [
                _QuickAction(
                  icon: Icons.groups,
                  color: AppColors.gold,
                  title: 'navigation.squad'.tr(),
                  subtitle: 'dashboard.playerCount'.tr(namedArgs: {'count': provider.squadPlayers.length.toString()}),
                  onTap: () => _push(context, const SquadScreen()),
                ),
                _QuickAction(
                  icon: Icons.swap_horiz,
                  color: AppColors.green,
                  title: 'navigation.transfer'.tr(),
                  subtitle: 'dashboard.offerCount'.tr(namedArgs: {'count': pendingOffers.toString()}),
                  badge: pendingOffers > 0 ? pendingOffers : null,
                  onTap: () => _push(context, const TransferMarketScreen()),
                ),
                _QuickAction(
                  icon: Icons.calendar_month,
                  color: AppColors.red,
                  title: 'navigation.calendar'.tr(),
                  subtitle: 'dashboard.matchCount'.tr(namedArgs: {'count': provider.fixtures.length.toString()}),
                  onTap: () => _push(context, const MatchScheduleScreen(), title: 'navigation.calendar'.tr()),
                ),
                _QuickAction(
                  icon: Icons.diamond,
                  color: AppColors.blue,
                  title: 'dashboard.market'.tr(),
                  subtitle: 'dashboard.diamondCount'.tr(namedArgs: {'count': provider.diamonds.toString()}),
                  onTap: () => _push(context, const MarketScreen()),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 13, 18, 24),
            child: _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$leagueName · ${'navigation.table'.tr()}',
                          style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold, fontSize: 10.5, letterSpacing: 1)),
                      GestureDetector(
                        onTap: () => _push(context, const LeagueTableScreen(), title: 'navigation.table'.tr()),
                        child: Text('dashboard.seeAll'.tr(), style: const TextStyle(color: AppColors.goldLight, fontWeight: FontWeight.bold, fontSize: 11.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (standings.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('dashboard.noStandingsYet'.tr(), style: const TextStyle(color: AppColors.textMuted)),
                    )
                  else
                    ...standings.take(3).map((row) {
                      final rowClub = row['club'] as Map?;
                      final isMe = rowClub?['id'] == club.id;
                      final pos = standings.indexOf(row) + 1;
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
                        decoration: isMe
                            ? BoxDecoration(color: AppColors.gold.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(8))
                            : null,
                        child: Row(
                          children: [
                            SizedBox(width: 22, child: Text('$pos', style: TextStyle(color: isMe ? AppColors.goldLight : AppColors.textMuted, fontWeight: FontWeight.bold))),
                            ClubBadge(clubName: rowClub?['name']?.toString() ?? '?', kind: isMe ? ClubBadgeKind.home : ClubBadgeKind.neutral, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(rowClub?['name']?.toString() ?? '?', style: TextStyle(color: isMe ? AppColors.goldLight : AppColors.textPrimary, fontWeight: isMe ? FontWeight.bold : FontWeight.w500))),
                            SizedBox(width: 30, child: Text('${row['played'] ?? 0}', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted))),
                            SizedBox(width: 40, child: Text('${row['points'] ?? 0}', textAlign: TextAlign.right, style: TextStyle(color: isMe ? AppColors.goldLight : AppColors.textPrimary, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  /// Pushes [screen] as a standalone route. Screens that already provide
  /// their own Scaffold/AppBar (Squad, Tactics, Transfer Market) are pushed
  /// as-is; screens designed as bare tab content for RootShell (League
  /// Table, Match Schedule - no Scaffold of their own, since RootShell
  /// supplies the chrome when they're a tab) need [title] so they get a
  /// Scaffold/AppBar/back button here too, otherwise they render with no
  /// safe-area padding and no way back.
  static void _push(BuildContext context, Widget screen, {String? title}) {
    final routeBody = title == null ? screen : Scaffold(appBar: AppBar(title: Text(title)), body: screen);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => routeBody));
  }

  static Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.cardTop, AppColors.cardBottom]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: child,
    );
  }

  static List<FormResult> _recentForm(GameProvider provider, String clubId) {
    final played = provider.fixtures.where((f) => f.status == 'Tamamlandı').toList()
      ..sort((a, b) => b.kickoff.compareTo(a.kickoff));
    return played.take(5).toList().reversed.map((f) {
      final myScore = f.isHome ? f.homeScore : f.awayScore;
      final oppScore = f.isHome ? f.awayScore : f.homeScore;
      if (myScore > oppScore) return FormResult.win;
      if (myScore < oppScore) return FormResult.loss;
      return FormResult.draw;
    }).toList();
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.club, required this.nextFixture, required this.standings, required this.myPosition});

  final dynamic club;
  final MatchFixture? nextFixture;
  final List<Map<String, dynamic>> standings;
  final int? myPosition;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -1.3),
          radius: 1.3,
          colors: [Color(0xFF23375C), Color(0xFF16233D), AppColors.background],
          stops: [0, 0.45, 1],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClubBadge(clubName: club.name as String, kind: ClubBadgeKind.home, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(club.name as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
                    Text('dashboard.manager'.tr(), style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                  ],
                ),
              ),
              _Pill(icon: AppAssets.coinGold, label: '${(club.budget as int) ~/ 1000}K'),
            ],
          ),
          const SizedBox(height: 14),
          _MatchCard(nextFixture: nextFixture, myPosition: myPosition),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});
  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xE6141E34), Color(0xE60C1322)]),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(icon, width: 14, height: 14),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _MatchCard extends StatefulWidget {
  const _MatchCard({required this.nextFixture, required this.myPosition});
  final MatchFixture? nextFixture;
  final int? myPosition;

  @override
  State<_MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<_MatchCard> {
  Timer? _timer;
  bool _isScouting = false;
  bool _isHidingTactics = false;
  bool _isSendingToCamp = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool _isWithinScoutWindow(MatchFixture f) {
    final remaining = f.kickoff.difference(DateTime.now());
    return remaining <= const Duration(minutes: 15) && remaining > Duration.zero;
  }

  Future<void> _scoutOpponent(BuildContext context, MatchFixture f) async {
    if (f.opponentClubId == null) return;
    setState(() => _isScouting = true);
    try {
      final report = await context.read<GameProvider>().scoutOpponent(f.id);
      if (!context.mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OpponentScoutScreen(opponentName: f.opponentName, report: report),
      ));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isScouting = false);
    }
  }

  Future<void> _hideTactics(BuildContext context) async {
    setState(() => _isHidingTactics = true);
    try {
      await context.read<GameProvider>().hideTacticsForNextMatch();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('dashboard.tacticsHiddenSuccess'.tr())),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isHidingTactics = false);
    }
  }

  Future<void> _sendToCamp(BuildContext context) async {
    setState(() => _isSendingToCamp = true);
    try {
      await context.read<GameProvider>().sendTeamToCamp();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('dashboard.campSentSuccess'.tr())),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isSendingToCamp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nextFixture = widget.nextFixture;
    if (nextFixture == null) {
      return DashboardScreen._card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(child: Text('dashboard.noUpcomingMatch'.tr(), style: const TextStyle(color: AppColors.textMuted))),
        ),
      );
    }
    final f = nextFixture!;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: Image.asset(AppAssets.pitchTile, fit: BoxFit.cover)),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.82), Colors.black.withValues(alpha: 0.55), Colors.black.withValues(alpha: 0.78)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('dashboard.nextMatchWeek'.tr(namedArgs: {'week': f.week.toString()}),
                        style: const TextStyle(fontSize: 10.5, letterSpacing: 1.4, fontWeight: FontWeight.bold, color: AppColors.goldLight)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white24)),
                      child: Text(f.isHome ? 'dashboard.home'.tr() : 'dashboard.away'.tr(), style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          ClubBadge(clubName: f.isHome ? 'dashboard.you'.tr() : f.opponentName, kind: f.isHome ? ClubBadgeKind.home : ClubBadgeKind.away, size: 52),
                          const SizedBox(height: 6),
                          Text(f.isHome ? 'dashboard.you'.tr() : f.opponentName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text(DateFormat('HH:mm').format(f.kickoff.toLocal()),
                            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99), border: Border.all(color: AppColors.gold.withValues(alpha: 0.3))),
                          child: Text(DateFormat('dd.MM').format(f.kickoff.toLocal()), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.goldLight)),
                        ),
                      ],
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          ClubBadge(clubName: f.isHome ? f.opponentName : 'dashboard.you'.tr(), kind: f.isHome ? ClubBadgeKind.away : ClubBadgeKind.home, size: 52),
                          const SizedBox(height: 6),
                          Text(f.isHome ? f.opponentName : 'dashboard.you'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GoldButton(
                  height: 44,
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => Scaffold(appBar: AppBar(title: Text('navigation.calendar'.tr())), body: const MatchScheduleScreen()),
                  )),
                  label: 'navigation.calendar'.tr(),
                ),
                if (_isWithinScoutWindow(f) && f.opponentClubId != null) ...[
                  const SizedBox(height: 10),
                  GlassButton(
                    height: 44,
                    isLoading: _isScouting,
                    onPressed: _isScouting ? null : () => _scoutOpponent(context, f),
                    label: 'dashboard.scoutOpponent'.tr(),
                  ),
                ],
                Builder(builder: (context) {
                  final club = context.watch<GameProvider>().activeClub;
                  if (club == null) return const SizedBox.shrink();
                  final tacticAlreadyHidden = club.tacticHiddenForMatchId == f.id;
                  final campAlreadyActive = club.campActiveForMatchId == f.id;
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: GlassButton(
                            height: 44,
                            isLoading: _isHidingTactics,
                            onPressed: (_isHidingTactics || tacticAlreadyHidden || !club.hasTacticHideAvailable)
                                ? null
                                : () => _hideTactics(context),
                            label: tacticAlreadyHidden
                                ? 'dashboard.tacticsHiddenActive'.tr()
                                : 'dashboard.hideTactics'.tr(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GlassButton(
                            height: 44,
                            isLoading: _isSendingToCamp,
                            onPressed: (_isSendingToCamp || campAlreadyActive || !club.hasCampAvailable)
                                ? null
                                : () => _sendToCamp(context),
                            label: campAlreadyActive
                                ? 'dashboard.campActive'.tr()
                                : 'dashboard.sendToCamp'.tr(),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap, this.badge});

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          DashboardScreen._card(
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.textPrimary)),
                      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (badge != null)
            Positioned(
              top: -7,
              right: -5,
              child: Container(
                constraints: const BoxConstraints(minWidth: 21, minHeight: 21),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(99), border: Border.all(color: AppColors.background, width: 2)),
                alignment: Alignment.center,
                child: Text('$badge', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}
