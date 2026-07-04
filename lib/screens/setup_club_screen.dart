import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/club_info.dart';
import '../providers/game_provider.dart';
import '../repositories/supabase_repository.dart';

class SetupClubScreen extends StatefulWidget {
  const SetupClubScreen({super.key});

  @override
  State<SetupClubScreen> createState() => _SetupClubScreenState();
}

class _SetupClubScreenState extends State<SetupClubScreen> {
  final _clubNameController = TextEditingController();
  final _repository = SupabaseRepository();
  bool _isLoading = true;
  List<ClubInfo> _availableClubs = <ClubInfo>[];

  @override
  void initState() {
    super.initState();
    _loadClubInitialization();
  }

  Future<void> _loadClubInitialization() async {
    try {
      final availableClubs = await _repository.loadAvailableClubs();
      if (!mounted) return;
      setState(() {
        _availableClubs = availableClubs;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kulüp bilgileri yüklenirken hata oluştu: ${error.toString()}')),
      );
    }
  }

  Future<void> _createClub() async {
    if (_clubNameController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);

    try {
      await _repository.createClub(_clubNameController.text.trim());
      await context.read<GameProvider>().refreshGameState();
      _navigateToRoot();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kulüp oluşturulurken hata oluştu: ${error.toString()}')),
      );
    }
  }

  Future<void> _claimClub(String clubId) async {
    setState(() => _isLoading = true);

    try {
      await _repository.claimClub(clubId);
      await context.read<GameProvider>().refreshGameState();
      _navigateToRoot();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kulüp seçilirken hata oluştu: ${error.toString()}')),
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
      appBar: AppBar(title: Text('Kulüp Kurulumu'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Aktif bir kulübünüz bulunamadı. Aşağıdan bir kulüp seçin veya kendinize özel bir kulüp oluşturun.'.tr(),
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    if (_availableClubs.isNotEmpty) ...[
                      Text('Mevcut Kulüpler'.tr(), style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      ..._availableClubs.map((club) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(club.name),
                            subtitle: Text('Bütçe: ${club.budget}'),
                            trailing: ElevatedButton(
                              onPressed: () => _claimClub(club.id),
                              child: Text('Seç'.tr()),
                            ),
                          ),
                        );
                      }),
                      const Divider(height: 32),
                    ],
                    Text('Yeni Kulüp Oluştur'.tr(), style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _clubNameController,
                      decoration: InputDecoration(
                        labelText: 'Kulüp Adı'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _createClub,
                      child: Text('Kulüp Oluştur'.tr()),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
