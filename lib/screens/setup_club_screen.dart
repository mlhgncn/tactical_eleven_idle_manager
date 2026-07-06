import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/club_info.dart';
import '../providers/game_provider.dart';

class SetupClubScreen extends StatefulWidget {
  SetupClubScreen({super.key});

  @override
  State<SetupClubScreen> createState() => _SetupClubScreenState();
}

class _SetupClubScreenState extends State<SetupClubScreen> {
  final _clubNameController = TextEditingController();
  bool _isLoading = true;
  List<ClubInfo> _availableClubs = <ClubInfo>[];

  @override
  void initState() {
    super.initState();
    _loadClubInitialization();
  }

  Future<void> _loadClubInitialization() async {
    try {
      final availableClubs = await context.read<GameProvider>().loadAvailableClubs();
      if (!mounted) return;
      setState(() {
        _availableClubs = availableClubs;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('clubSetup.errors.load'.tr(namedArgs: {'error': error.toString()}))),
      );
    }
  }

  Future<void> _createClub() async {
    if (_clubNameController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);

    try {
      await context.read<GameProvider>().createClub(_clubNameController.text.trim());
      _navigateToRoot();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('clubSetup.errors.create'.tr(namedArgs: {'error': error.toString()}))),
      );
    }
  }

  Future<void> _claimClub(String clubId) async {
    setState(() => _isLoading = true);

    try {
      await context.read<GameProvider>().claimClub(clubId);
      _navigateToRoot();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('clubSetup.errors.claim'.tr(namedArgs: {'error': error.toString()}))),
      );
    }
  }

  void _navigateToRoot() {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/root');
  }

  @override
  void dispose() {
    _clubNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('clubSetup.title'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'clubSetup.description'.tr(),
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    if (_availableClubs.isNotEmpty) ...[
                      Text('clubSetup.existingClubs'.tr(), style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      ..._availableClubs.map((club) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(club.name),
                            subtitle: Text('clubSetup.budget'.tr(namedArgs: {'budget': club.budget.toString()})),
                            trailing: ElevatedButton(
                              onPressed: () => _claimClub(club.id),
                              child: Text('clubSetup.select'.tr()),
                            ),
                          ),
                        );
                      }),
                      const Divider(height: 32),
                    ],
                    Text('clubSetup.newClub'.tr(), style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _clubNameController,
                      decoration: InputDecoration(
                        labelText: 'clubSetup.clubName'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _createClub,
                      child: Text('clubSetup.create'.tr()),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
