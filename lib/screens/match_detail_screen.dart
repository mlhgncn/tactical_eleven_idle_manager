import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/match_fixture.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/club_badge.dart';

/// Matches are resolved instantly server-side (pg_cron simulates the whole
/// 90 minutes in one go and bulk-inserts all match_events at once), so
/// there's no real live feed to subscribe to. To still give the "watching
/// it happen" feeling instead of dumping the full event list at once, this
/// screen replays the already-recorded events on a compressed clock: 90
/// simulated minutes play out over ~75 real seconds, the scoreboard climbs
/// as goal events are crossed, and the event list reveals one row at a
/// time. A finished match just replays from minute 0 every time it's
/// opened; a match whose kickoff is still in the future shows a countdown
/// instead.
class MatchDetailScreen extends StatefulWidget {
  const MatchDetailScreen({super.key, required this.fixture});

  final MatchFixture fixture;

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  static const int _totalMinutes = 90;
  static const Duration _replayDuration = Duration(seconds: 75);
  static const Duration _tick = Duration(milliseconds: 200);

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _events = [];

  Timer? _replayTimer;
  Timer? _countdownTimer;
  double _elapsedMinute = 0;
  bool _replayFinished = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _replayTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    _replayTimer?.cancel();
    _countdownTimer?.cancel();
    setState(() {
      _loading = true;
      _error = null;
      _elapsedMinute = 0;
      _replayFinished = false;
    });

    final fixture = widget.fixture;
    final now = DateTime.now();
    if (fixture.status != 'Tamamlandı') {
      // Not played yet - just tick a countdown to kickoff, no events to fetch.
      setState(() => _loading = false);
      if (fixture.kickoff.isAfter(now)) {
        _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
          if (mounted) setState(() {});
        });
      }
      return;
    }

    final provider = context.read<GameProvider>();
    try {
      final events = await provider.repo.loadMatchEvents(fixture.id);
      events.sort((a, b) => ((a['minute'] as num?) ?? 0).compareTo((b['minute'] as num?) ?? 0));
      _events = events;
    } catch (e) {
      _events = [];
      _error = 'matchDetail.loadFailed'.tr(namedArgs: {'error': e.toString().replaceAll('Exception: ', '')});
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (_error == null) _startReplay();
  }

  void _startReplay() {
    final ticksTotal = _replayDuration.inMilliseconds / _tick.inMilliseconds;
    final minutePerTick = _totalMinutes / ticksTotal;
    _replayTimer = Timer.periodic(_tick, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _elapsedMinute = (_elapsedMinute + minutePerTick).clamp(0, _totalMinutes.toDouble());
        if (_elapsedMinute >= _totalMinutes) {
          _replayFinished = true;
          timer.cancel();
        }
      });
    });
  }

  void _skipToEnd() {
    _replayTimer?.cancel();
    setState(() {
      _elapsedMinute = _totalMinutes.toDouble();
      _replayFinished = true;
    });
  }

  static const _eventIcons = {
    'goal': Icons.sports_soccer,
    'penalty': Icons.adjust,
    'yellow_card': Icons.square,
    'red_card': Icons.square,
    'injury': Icons.local_hospital,
    'substitution': Icons.swap_horiz,
  };

  static const _eventColors = {
    'goal': AppColors.green,
    'penalty': AppColors.gold,
    'yellow_card': Color(0xFFE8C547),
    'red_card': AppColors.red,
    'injury': AppColors.red,
    'substitution': AppColors.blue,
  };

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final fixture = widget.fixture;
    final myClubId = provider.activeClub?.id;
    final isPlayed = fixture.status == 'Tamamlandı';
    final isReplaying = isPlayed && !_replayFinished && _error == null && !_loading;

    final visibleEvents = isPlayed
        ? _events.where((e) => ((e['minute'] as num?) ?? 0) <= _elapsedMinute).toList()
        : const <Map<String, dynamic>>[];

    int homeScore = 0;
    int awayScore = 0;
    if (isPlayed) {
      final homeClubId = fixture.isHome ? myClubId : fixture.opponentClubId;
      for (final event in visibleEvents) {
        if (event['event_type'] != 'goal' && event['event_type'] != 'penalty') continue;
        if (event['club_id'] == homeClubId) {
          homeScore++;
        } else {
          awayScore++;
        }
      }
    }
    // Once the replay is done (or on any load that isn't a fresh replay),
    // trust the authoritative final score from the fixture instead of the
    // event-derived tally, in case of any goal/penalty counting edge case.
    if (_replayFinished) {
      homeScore = fixture.homeScore;
      awayScore = fixture.awayScore;
    }

    return Scaffold(
      appBar: AppBar(title: Text('matchDetail.title'.tr())),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isReplaying) ...[
                          const _PulsingDot(),
                          const SizedBox(width: 6),
                          Text('matchDetail.liveLabel'.tr(),
                              style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
                          const SizedBox(width: 8),
                          Text("${_elapsedMinute.toInt()}'", style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold, fontSize: 11)),
                        ] else if (_replayFinished) ...[
                          Text('matchDetail.finishedLabel'.tr(),
                              style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
                        ] else
                          Text(
                              '${'matchSchedule.weekLabel'.tr(namedArgs: {'week': fixture.week.toString()})} · ${DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(fixture.kickoff.toLocal())}',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              ClubBadge(clubName: fixture.isHome ? 'dashboard.you'.tr() : fixture.opponentName, kind: fixture.isHome ? ClubBadgeKind.home : ClubBadgeKind.away, size: 44),
                              const SizedBox(height: 6),
                              Text(fixture.isHome ? 'dashboard.you'.tr() : fixture.opponentName, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            isPlayed ? '$homeScore - $awayScore' : 'matchDetail.vsLabel'.tr(),
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              ClubBadge(clubName: fixture.isHome ? fixture.opponentName : 'dashboard.you'.tr(), kind: fixture.isHome ? ClubBadgeKind.away : ClubBadgeKind.home, size: 44),
                              const SizedBox(height: 6),
                              Text(fixture.isHome ? fixture.opponentName : 'dashboard.you'.tr(), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (isReplaying) ...[
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (_elapsedMinute / _totalMinutes).clamp(0, 1),
                          minHeight: 4,
                          backgroundColor: AppColors.cardBorder,
                          valueColor: const AlwaysStoppedAnimation(AppColors.red),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _skipToEnd,
                        child: Text('matchDetail.skipToEnd'.tr(), style: const TextStyle(color: AppColors.textMuted)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (!isPlayed)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                  child: Text(
                    fixture.kickoff.isAfter(DateTime.now())
                        ? 'matchDetail.kickoffCountdown'.tr(namedArgs: {
                            'minutes': fixture.kickoff.difference(DateTime.now()).inMinutes.toString(),
                          })
                        : 'matchDetail.notPlayedYet'.tr(),
                    style: const TextStyle(color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(child: Text(_error!, style: const TextStyle(color: AppColors.red), textAlign: TextAlign.center)),
              )
            else if (_events.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(child: Text('matchDetail.noEventsRecorded'.tr(), style: const TextStyle(color: AppColors.textMuted))),
              )
            else ...[
              if (isReplaying)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('matchDetail.replayNotice'.tr(),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic)),
                ),
              Text('matchDetail.matchSummary'.tr(), style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
              const SizedBox(height: 10),
              ...visibleEvents.map((event) {
                final eventType = event['event_type'] as String? ?? '';
                final minute = (event['minute'] as num?)?.toInt() ?? 0;
                final description = event['description'] as String? ?? '';
                final isMine = myClubId != null && event['club_id'] == myClubId;
                final icon = _eventIcons[eventType] ?? Icons.info_outline;
                final color = _eventColors[eventType] ?? AppColors.textMuted;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 38,
                        child: Text("$minute'", textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      Container(
                        width: 30,
                        height: 30,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.16), shape: BoxShape.circle, border: Border.all(color: color.withValues(alpha: 0.35))),
                        child: Icon(icon, size: 15, color: color),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            description,
                            style: TextStyle(fontWeight: isMine ? FontWeight.bold : FontWeight.normal, color: isMine ? AppColors.textPrimary : AppColors.textMuted),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.3, end: 1.0).animate(_controller),
      child: const SizedBox(
        width: 8,
        height: 8,
        child: DecoratedBox(decoration: BoxDecoration(color: AppColors.red, shape: BoxShape.circle)),
      ),
    );
  }
}
