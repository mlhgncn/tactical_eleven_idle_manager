import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('menu.settings'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: () async {
                await context.setLocale(const Locale('tr'));
              },
              icon: const Icon(Icons.language),
              label: Text('Türkçe'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () async {
                await context.setLocale(const Locale('en'));
              },
              icon: const Icon(Icons.language),
              label: Text('English'),
            ),
            const SizedBox(height: 24),
            Text('Uygulama dili değiştiğinde tüm metinler güncellenecektir.').tr(),
          ],
        ),
      ),
    );
  }
}
