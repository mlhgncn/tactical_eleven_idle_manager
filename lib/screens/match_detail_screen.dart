import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/match_fixture.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/club_badge.dart';

class MatchDetailScreen extends StatefulWidget {
  const MatchDetailScreen({super.key, required this.fixture});

  final MatchFixture fixture;

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _events = [];

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
    final provider = context.read<GameProvider>();
    try {
      final events = await provider.repo.loadMatchEvents(widget.fixture.id);
      events.sort((a, b) => ((a['minute'] as num?) ?? 0).compareTo((b['minute'] as num?) ?? 0));
      _events = events;
    } catch (e) {
      _events = [];
      _error = 'matchDetail.loadFailed'.tr(namedArgs: {'error': e.toString().replaceAll('Exception: ', '')});
    }
    if (mounted) setState(() => _loading = false);
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
                    Text(
                        '${'matchSchedule.weekLabel'.tr(namedArgs: {'week': fixture.week.toString()})} · ${DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(fixture.kickoff.toLocal())}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
                            isPlayed ? '${fixture.homeScore} - ${fixture.awayScore}' : 'matchDetail.vsLabel'.tr(),
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (!isPlayed)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(child: Text('matchDetail.notPlayedYet'.tr(), style: const TextStyle(color: AppColors.textMuted))),
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
              Text('matchDetail.matchSummary'.tr(), style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
              const SizedBox(height: 10),
              ..._events.map((event) {
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
