import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../services/auth_service.dart';

import '../providers/game_provider.dart';
import 'club_finance_screen.dart';
import 'inbox_screen.dart';
import 'match_schedule_screen.dart';
import 'squad_screen.dart';
import 'tactics_screen.dart';

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
    const TacticsScreen(),
    const MatchScheduleScreen(),
    const InboxScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  final AuthService _authService = AuthService();

  Future<void> _signOut() async {
    await _authService.signOut();
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
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Finans'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Kadro'),
          BottomNavigationBarItem(icon: Icon(Icons.sports_soccer), label: 'Taktik'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Takvim'),
          BottomNavigationBarItem(icon: Icon(Icons.inbox), label: 'Gelen'),
        ],
      ),
    );
  }
}
