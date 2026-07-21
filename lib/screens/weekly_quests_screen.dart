import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/weekly_quest.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snackbar.dart';

class WeeklyQuestsScreen extends StatefulWidget {
  const WeeklyQuestsScreen({super.key});

  @override
  State<WeeklyQuestsScreen> createState() => _WeeklyQuestsScreenState();
}

class _WeeklyQuestsScreenState extends State<WeeklyQuestsScreen> {
  bool _loading = true;
  String? _error;
  List<WeeklyQuest> _quests = [];
  String? _claimingKey;

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
      _quests = await context.read<GameProvider>().loadWeeklyQuests();
    } catch (e) {
      _quests = [];
      _error = 'weeklyQuests.loadFailed'.tr(namedArgs: {'error': e.toString().replaceAll('Exception: ', '')});
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _claim(WeeklyQuest quest) async {
    setState(() => _claimingKey = quest.questKey);
    try {
      final result = await context.read<GameProvider>().claimWeeklyQuestReward(quest.questKey);
      if (!mounted) return;
      final gp = (result['gp_awarded'] as num?)?.toInt() ?? 0;
      final diamonds = (result['diamonds_awarded'] as num?)?.toInt() ?? 0;
      AppSnackBar.showSuccess(context, 'weeklyQuests.claimSuccess'.tr(namedArgs: {'gp': gp.toString(), 'diamonds': diamonds.toString()}));
      await _load();
    } catch (error) {
      if (!mounted) return;
      AppSnackBar.showErrorFromException(context, error);
    } finally {
      if (mounted) setState(() => _claimingKey = null);
    }
  }

  static const _metricIcons = {
    'play_matches': Icons.sports_soccer,
    'win_matches': Icons.emoji_events,
    'develop_players': Icons.trending_up,
  };

  String _metricLabel(String metric, int target) {
    switch (metric) {
      case 'win_matches':
        return 'weeklyQuests.metricWinMatches'.tr(namedArgs: {'target': target.toString()});
      case 'develop_players':
        return 'weeklyQuests.metricDevelopPlayers'.tr(namedArgs: {'target': target.toString()});
      default:
        return 'weeklyQuests.metricPlayMatches'.tr(namedArgs: {'target': target.toString()});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('weeklyQuests.title'.tr())),
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
                  else if (_quests.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(child: Text('weeklyQuests.empty'.tr(), style: const TextStyle(color: AppColors.textMuted))),
                    )
                  else ...[
                    Text('weeklyQuests.subtitle'.tr(), style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                    const SizedBox(height: 16),
                    ..._quests.map((quest) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _QuestCard(
                            quest: quest,
                            icon: _metricIcons[quest.metric] ?? Icons.flag,
                            label: _metricLabel(quest.metric, quest.target),
                            isLoading: _claimingKey == quest.questKey,
                            onClaim: () => _claim(quest),
                          ),
                        )),
                  ],
                ],
              ),
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.quest, required this.icon, required this.label, required this.isLoading, required this.onClaim});

  final WeeklyQuest quest;
  final IconData icon;
  final String label;
  final bool isLoading;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final isComplete = quest.isComplete;
    final isClaimed = quest.claimed;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardTop,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isClaimed ? AppColors.green.withValues(alpha: 0.4) : AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: isClaimed ? AppColors.green : AppColors.gold, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('${quest.progress}/${quest.target}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              if (isClaimed)
                const Icon(Icons.check_circle, color: AppColors.green, size: 20)
              else
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: (isComplete && !isLoading) ? onClaim : null,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                    child: isLoading
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text('weeklyQuests.claimButton'.tr(), style: const TextStyle(fontSize: 12)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (quest.progress / quest.target).clamp(0, 1),
              minHeight: 6,
              backgroundColor: AppColors.cardBorder,
              valueColor: AlwaysStoppedAnimation(isClaimed ? AppColors.green : AppColors.gold),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (quest.gpReward > 0) ...[
                const Text('💰', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 3),
                Text('${quest.gpReward} GP', style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.w600)),
              ],
              if (quest.gpReward > 0 && quest.diamondReward > 0) const SizedBox(width: 10),
              if (quest.diamondReward > 0) ...[
                const Icon(Icons.diamond, color: AppColors.blue, size: 12),
                const SizedBox(width: 3),
                Text('${quest.diamondReward}', style: const TextStyle(color: AppColors.blue, fontSize: 11.5, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
