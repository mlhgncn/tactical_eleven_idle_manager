import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/game_provider.dart';
import 'club_finance_screen.dart';
import 'squad_screen.dart';
import 'transfer_market_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = <Widget>[
    const ClubFinanceScreen(),
    const SquadScreen(),
    const TransferMarketScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/auth');
  }

  @override
  Widget build(BuildContext context) {
    final activeClub = context.select((GameProvider provider) => provider.activeClub);
    final title = activeClub == null ? 'Menajerlik Paneli'.tr() : 'Kulüp: ${activeClub.id.substring(0, 6)}';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
            tooltip: 'Ayarlar',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Çıkış Yap',
          )
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'menu.play'.tr()),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'menu.squad'.tr()),
          BottomNavigationBarItem(icon: Icon(Icons.sports_soccer), label: 'menu.tactics'.tr()),
        ],
      ),
    );
  }
}
