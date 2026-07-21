import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../widgets/app_snackbar.dart';
import 'profile_screen.dart';

final _authService = AuthService();

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('settings.title'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _SettingsBody(),
      ),
    );
  }
}

class _SettingsBody extends StatefulWidget {
  @override
  State<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<_SettingsBody> {
  bool _notificationsEnabled = true;
  bool _loading = true;
  bool _isLeaving = false;
  bool _isDeletingAccount = false;

  @override
  void initState() {
    super.initState();
    _loadPref();
  }

  Future<void> _loadPref() async {
    try {
      final enabled = NotificationService.instance.enabled;
      setState(() {
        _notificationsEnabled = enabled;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggle(bool value) async {
    setState(() => _notificationsEnabled = value);
    await NotificationService.instance.setEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
          },
          icon: const Icon(Icons.person),
          label: Text('settings.profile'.tr()),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () async {
            await context.setLocale(const Locale('tr'));
          },
          icon: const Icon(Icons.language),
          label: Text('settings.language_turkish'.tr()),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () async {
            await context.setLocale(const Locale('en'));
          },
          icon: const Icon(Icons.language),
          label: Text('settings.language_english'.tr()),
        ),
        const SizedBox(height: 24),
        Text('settings.language_notice'.tr()),
        const SizedBox(height: 24),
        ListTile(
          title: Text('settings.notifications'.tr()),
          subtitle: Text('settings.notifications_desc'.tr()),
          trailing: _loading
              ? const CircularProgressIndicator()
              : Switch(
                  value: _notificationsEnabled,
                  onChanged: (v) => _toggle(v),
                ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
          onPressed: _isLeaving ? null : () => _confirmLeaveTeam(context),
          icon: _isLeaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.exit_to_app),
          label: Text('settings.leave_team'.tr()),
        ),
        const SizedBox(height: 12),
        // Anonymous accounts have no password to sign back in with - signing
        // out would strand the player's club permanently unreachable. Send
        // them to Profile to claim a real account first instead of exposing
        // sign-out at all.
        if (_authService.isAnonymous)
          Text(
            'settings.guest_logout_notice'.tr(),
            style: const TextStyle(color: Colors.orange, fontSize: 12.5),
          )
        else
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              await _authService.signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
            },
            icon: const Icon(Icons.logout),
            label: Text('navigation.logout_tooltip'.tr()),
          ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          onPressed: _isDeletingAccount ? null : () => _confirmDeleteAccount(context),
          icon: _isDeletingAccount
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.delete_forever),
          label: Text('settings.delete_account'.tr()),
        ),
      ],
    );
  }

  Future<void> _confirmLeaveTeam(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('settings.leave_team_confirm_title'.tr()),
        content: Text('settings.leave_team_confirm_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('settings.leave_team_cancel'.tr()),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('settings.leave_team_confirm_action'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    setState(() => _isLeaving = true);
    try {
      await context.read<GameProvider>().leaveClub();
      if (!context.mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/setup-club', (route) => false);
    } catch (error) {
      if (context.mounted) {
        AppSnackBar.showErrorFromException(context, error);
      }
    } finally {
      if (mounted) setState(() => _isLeaving = false);
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('settings.delete_account_confirm_title'.tr()),
        content: Text('settings.delete_account_confirm_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('settings.leave_team_cancel'.tr()),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('settings.delete_account_confirm_action'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    setState(() => _isDeletingAccount = true);
    try {
      await context.read<GameProvider>().deleteAccount();
      await _authService.signOut();
      if (!context.mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
    } catch (error) {
      if (context.mounted) {
        AppSnackBar.showErrorFromException(context, error);
      }
    } finally {
      if (mounted) setState(() => _isDeletingAccount = false);
    }
  }
}
