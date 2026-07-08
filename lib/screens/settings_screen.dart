import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../services/auth_service.dart';
import '../services/notification_service.dart';

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
}
