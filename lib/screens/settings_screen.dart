import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'profile_screen.dart';

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
          label: const Text('Profilim'),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () async {
            await context.setLocale(const Locale('tr'));
          },
          icon: const Icon(Icons.language),
          label: const Text('Türkçe'),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () async {
            await context.setLocale(const Locale('en'));
          },
          icon: const Icon(Icons.language),
          label: const Text('English'),
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
          label: const Text('Takımı Bırak'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () async {
            await AuthService().signOut();
            if (!context.mounted) return;
            Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
          },
          icon: const Icon(Icons.logout),
          label: Text('navigation.logout_tooltip'.tr()),
        ),
      ],
    );
  }

  Future<void> _confirmLeaveTeam(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Takımı bırakmak istediğine emin misin?'),
        content: const Text(
          'Mevcut kulübün elinden alınacak ve başkası tarafından devralınabilir hale gelecek. '
          'Bu işlem geri alınamaz; yeniden lig oluşturman ya da bir davet koduyla katılman gerekecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Evet, Bırak'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLeaving = false);
    }
  }
}
