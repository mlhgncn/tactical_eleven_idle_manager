import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/leaderboard_entry.dart';
import '../models/profile.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/level_frame.dart';

/// Server-wide ranking by league titles (tiebreak: total wins, then best
/// win streak), independent of any single league's table. Only accounts
/// with a username set are ranked - matches get_global_leaderboard's RLS
/// workaround, which filters the same way to avoid surfacing anonymous
/// rows with no display name.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _loading = true;
  String? _error;
  List<LeaderboardEntry> _entries = [];
  LeaderboardEntry? _myRank;

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
      final results = await Future.wait([
        provider.loadGlobalLeaderboard(limit: 100),
        provider.loadMyLeaderboardRank(),
      ]);
      _entries = results[0] as List<LeaderboardEntry>;
      _myRank = results[1] as LeaderboardEntry?;
    } catch (e) {
      _entries = [];
      _error = 'leaderboard.loadFailed'.tr(namedArgs: {'error': e.toString().replaceAll('Exception: ', '')});
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final myUserId = context.read<GameProvider>().profile?.id;

    return Scaffold(
      appBar: AppBar(title: Text('leaderboard.title'.tr())),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 80),
                        child: Center(child: Text(_error!, style: const TextStyle(color: AppColors.red), textAlign: TextAlign.center)),
                      ),
                    ],
                  )
                : _entries.isEmpty
                    ? ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 80),
                            child: Center(child: Text('leaderboard.empty'.tr(), style: const TextStyle(color: AppColors.textMuted))),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          if (_myRank != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                              child: _LeaderboardRow(entry: _myRank!, isMe: true, highlight: true),
                            ),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _entries.length,
                              itemBuilder: (context, index) {
                                final entry = _entries[index];
                                return _LeaderboardRow(entry: entry, isMe: entry.id == myUserId, highlight: false);
                              },
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry, required this.isMe, required this.highlight});

  final LeaderboardEntry entry;
  final bool isMe;
  final bool highlight;

  static const _medalColors = {1: Color(0xFFE8C547), 2: Color(0xFFC6CCD8), 3: Color(0xFFCD7F32)};

  @override
  Widget build(BuildContext context) {
    final level = Profile.levelForTitles(entry.leagueTitles);
    final medalColor = _medalColors[entry.rank];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? AppColors.gold.withValues(alpha: 0.12) : AppColors.cardTop,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isMe ? AppColors.gold.withValues(alpha: 0.5) : AppColors.cardBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: medalColor != null
                ? Icon(Icons.emoji_events, color: medalColor, size: 20)
                : Text('${entry.rank}', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          LevelFrame(
            level: level,
            padding: 2,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.cardBottom,
              backgroundImage: entry.avatarUrl != null ? NetworkImage(entry.avatarUrl!) : null,
              child: entry.avatarUrl == null ? const Icon(Icons.person, size: 18, color: AppColors.textMuted) : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.username,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.bold, color: isMe ? AppColors.goldLight : AppColors.textPrimary),
                      ),
                    ),
                    if (entry.hasUnbeatenTitle) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.shield, size: 13, color: AppColors.blue),
                    ],
                  ],
                ),
                Text(
                  'leaderboard.statsLine'.tr(namedArgs: {
                    'titles': entry.leagueTitles.toString(),
                    'wins': entry.totalWins.toString(),
                  }),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          Text(
            entry.leagueTitles > 0 ? '${entry.leagueTitles} 🏆' : '${entry.totalWins} W',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.goldLight),
          ),
        ],
      ),
    );
  }
}
