import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/themed_button.dart';

class SetupClubScreen extends StatefulWidget {
  SetupClubScreen({super.key});

  @override
  State<SetupClubScreen> createState() => _SetupClubScreenState();
}

class _SetupClubScreenState extends State<SetupClubScreen> {
  final _clubNameController = TextEditingController();
  final _invitationCodeController = TextEditingController();
  bool _isLoading = false;
  bool _showJoinField = false;

  Future<void> _createLeague() async {
    if (_clubNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('clubSetup.errors.nameRequired'.tr())),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      await context.read<GameProvider>().createLeagueAndJoin(_clubNameController.text.trim());
      _navigateToRoot();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('clubSetup.errors.createLeague'.tr(namedArgs: {'error': error.toString()}))),
      );
    }
  }

  Future<void> _joinLeague() async {
    if (_invitationCodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('clubSetup.errors.codeRequired'.tr())),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      await context.read<GameProvider>().joinLeagueWithCode(_invitationCodeController.text.trim());
      _navigateToRoot();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('clubSetup.errors.joinLeague'.tr(namedArgs: {'error': error.toString()}))),
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
    _invitationCodeController.dispose();
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
                    Text('clubSetup.clubName'.tr(), style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _clubNameController,
                      decoration: InputDecoration(
                        labelText: 'clubSetup.clubName'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GoldButton(
                      onPressed: _createLeague,
                      label: 'clubSetup.createLeague'.tr(),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Expanded(child: Divider(color: AppColors.cardBorder)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('clubSetup.or'.tr(), style: const TextStyle(color: AppColors.textMuted)),
                        ),
                        const Expanded(child: Divider(color: AppColors.cardBorder)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (!_showJoinField)
                      GlassButton(
                        onPressed: () => setState(() => _showJoinField = true),
                        label: 'clubSetup.joinLeague'.tr(),
                      )
                    else ...[
                      Text('clubSetup.invitationCode'.tr(), style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _invitationCodeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'clubSetup.invitationCode'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GoldButton(
                        onPressed: _joinLeague,
                        label: 'clubSetup.joinConfirm'.tr(),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
