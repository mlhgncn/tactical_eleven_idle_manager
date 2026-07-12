import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/opponent_scout_report.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/async_state_builder.dart';
import 'opponent_scout_screen.dart';

/// Lists every opponent this club has previously scouted (persisted
/// server-side by scout_opponent) so a saved report can be reopened any
/// time - unlike producing a *new* scout, which stays gated to 15 minutes
/// before kickoff.
class ScoutedReportsScreen extends StatefulWidget {
  const ScoutedReportsScreen({super.key});

  @override
  State<ScoutedReportsScreen> createState() => _ScoutedReportsScreenState();
}

class _ScoutedReportsScreenState extends State<ScoutedReportsScreen> {
  List<SavedScoutReport>? _reports;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final reports = await context.read<GameProvider>().loadScoutedReports();
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reports = _reports ?? const <SavedScoutReport>[];
    return Scaffold(
      appBar: AppBar(title: Text('opponentScout.savedReportsTitle'.tr())),
      body: RefreshIndicator(
        onRefresh: _load,
        child: AsyncStateBuilder(
          isLoading: _isLoading,
          errorMessage: _errorMessage,
          isEmpty: reports.isEmpty,
          emptyBuilder: () => Center(child: Text('opponentScout.noSavedReports'.tr())),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final saved = reports[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.visibility)),
                  title: Text(saved.opponentName),
                  subtitle: Text(DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(saved.scoutedAt.toLocal())),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => OpponentScoutScreen(opponentName: saved.opponentName, report: saved.report),
                    ));
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
