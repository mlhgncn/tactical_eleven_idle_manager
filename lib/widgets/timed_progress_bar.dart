import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A live-updating progress bar + countdown for any timed development
/// (player growth, sponsor/stadium/facility/ticket upgrades). [totalDuration]
/// is the full length of the process (recomputed by the caller from the
/// same formula the server used to schedule [completesAt], since the
/// server only persists the completion timestamp, not the start time).
class TimedProgressBar extends StatefulWidget {
  const TimedProgressBar({
    super.key,
    required this.completesAt,
    required this.totalDuration,
    this.label,
  });

  final DateTime completesAt;
  final Duration totalDuration;
  final String? label;

  @override
  State<TimedProgressBar> createState() => _TimedProgressBarState();
}

class _TimedProgressBarState extends State<TimedProgressBar> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatRemaining(Duration d) {
    if (d.inDays > 0) return '${d.inDays}g ${d.inHours % 24}s kaldı';
    if (d.inHours > 0) return '${d.inHours}s ${d.inMinutes % 60}dk kaldı';
    if (d.inMinutes > 0) return '${d.inMinutes}dk ${d.inSeconds % 60}sn kaldı';
    return '${d.inSeconds}sn kaldı';
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.completesAt.difference(DateTime.now());
    final clampedRemaining = remaining.isNegative ? Duration.zero : remaining;
    final totalMs = widget.totalDuration.inMilliseconds > 0 ? widget.totalDuration.inMilliseconds : 1;
    final elapsedMs = (totalMs - clampedRemaining.inMilliseconds).clamp(0, totalMs);
    final progress = elapsedMs / totalMs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
          const SizedBox(height: 6),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress.toDouble(),
            minHeight: 8,
            backgroundColor: AppColors.cardBorder,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatRemaining(clampedRemaining),
          style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
