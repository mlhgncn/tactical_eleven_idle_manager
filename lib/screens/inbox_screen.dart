import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/inbox_message.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snackbar.dart';
import 'player_stats_screen.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  Future<void> _openRelatedPlayer(BuildContext context, String playerId) async {
    final provider = context.read<GameProvider>();
    final player = await provider.loadPlayerById(playerId);
    if (!context.mounted) return;
    if (player == null) {
      AppSnackBar.show(context, 'inbox.playerUnavailable'.tr());
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerStatsScreen(player: player)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final messages = provider.inboxMessages;

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => context.read<GameProvider>().refreshGameState(),
      child: messages.isEmpty
          ? ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 96),
                  child: Column(
                    children: [
                      Icon(Icons.mark_email_read_outlined, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text('inbox.empty'.tr(), style: const TextStyle(color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return _InboxMessageCard(
                  message: message,
                  onOpenPlayer: message.relatedPlayerId != null
                      ? () => _openRelatedPlayer(context, message.relatedPlayerId!)
                      : null,
                );
              },
            ),
    );
  }
}

class _InboxMessageCard extends StatelessWidget {
  const _InboxMessageCard({required this.message, this.onOpenPlayer});

  final InboxMessage message;
  final VoidCallback? onOpenPlayer;

  IconData get _categoryIcon {
    final t = message.title.toLowerCase();
    if (t.contains('transfer') || t.contains('teklif')) return Icons.swap_horiz;
    if (t.contains('sakat')) return Icons.medical_services_outlined;
    if (t.contains('ceza') || t.contains('kart')) return Icons.warning_amber_rounded;
    if (t.contains('başar') || t.contains('şampiyon') || t.contains('ödül')) return Icons.emoji_events_outlined;
    if (t.contains('banka') || t.contains('faiz')) return Icons.account_balance_outlined;
    if (t.contains('maç')) return Icons.sports_soccer;
    return Icons.mail_outline;
  }

  String _formatTimestamp() {
    final now = DateTime.now();
    final local = message.createdAt.toLocal();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'inbox.justNow'.tr();
    if (diff.inMinutes < 60) return 'inbox.minutesAgo'.tr(namedArgs: {'count': diff.inMinutes.toString()});
    if (diff.inHours < 24 && now.day == local.day) {
      return DateFormat('HH:mm').format(local);
    }
    if (diff.inDays < 7) return DateFormat('dd.MM').format(local);
    return DateFormat('dd.MM.yyyy').format(local);
  }

  Future<void> _toggleRead(BuildContext context) async {
    try {
      if (message.isRead) {
        await context.read<GameProvider>().markMessageAsUnread(message.id);
      } else {
        await context.read<GameProvider>().markMessageAsRead(message.id);
      }
    } catch (error) {
      if (context.mounted) {
        AppSnackBar.showError(context, 'inbox.markFailed'.tr(namedArgs: {'error': error.toString()}));
      }
      return;
    }
    if (context.mounted) {
      AppSnackBar.showSuccess(context, message.isRead ? 'inbox.markedAsUnread'.tr() : 'inbox.markedAsRead'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !message.isRead;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardTop,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isUnread ? AppColors.gold.withValues(alpha: 0.45) : AppColors.cardBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpenPlayer,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (isUnread ? AppColors.gold : AppColors.textMuted).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(_categoryIcon, size: 18, color: isUnread ? AppColors.goldLight : AppColors.textMuted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            message.title,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 14.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTimestamp(),
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message.body,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.3),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _toggleRead(context),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    isUnread ? Icons.circle : Icons.check_circle_outline,
                    size: isUnread ? 10 : 18,
                    color: isUnread ? AppColors.gold : AppColors.green.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
