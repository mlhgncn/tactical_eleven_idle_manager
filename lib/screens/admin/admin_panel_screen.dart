import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/game_provider.dart';
import 'admin_user_list_screen.dart';
import 'admin_club_list_screen.dart';
import 'admin_player_edit_screen.dart';
import 'admin_gift_code_screen.dart';
import 'admin_push_screen.dart';
import 'admin_event_screen.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    if (!provider.isAdmin) {
      return const Scaffold(body: Center(child: Text('Erişim reddedildi')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Yönetici Paneli')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Kullanıcılar'),
            subtitle: const Text('Tüm kullanıcıları listele ve yönet'),
            leading: const Icon(Icons.people),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminUserListScreen())),
          ),
          ListTile(
            title: const Text('Kulüpler'),
            subtitle: const Text('Kulüp listesi ve düzenleme'),
            leading: const Icon(Icons.sports_soccer),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminClubListScreen())),
          ),
          ListTile(
            title: const Text('Oyuncu Düzenle'),
            subtitle: const Text('Oyuncu bilgilerini düzenle'),
            leading: const Icon(Icons.edit),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminPlayerEditScreen())),
          ),
          ListTile(
            title: const Text('Hediye Kodu Oluştur'),
            leading: const Icon(Icons.card_giftcard),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminGiftCodeScreen())),
          ),
          ListTile(
            title: const Text('Push Bildirim Gönder'),
            leading: const Icon(Icons.notifications),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminPushScreen())),
          ),
          ListTile(
            title: const Text('Etkinlik Oluştur'),
            leading: const Icon(Icons.event),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminEventScreen())),
          ),
        ],
      ),
    );
  }
}
