import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../theme/app_assets.dart';

import '../providers/game_provider.dart';
import 'club_finance_screen.dart';
import 'dashboard_screen.dart';
import 'inbox_screen.dart';
import 'league_table_screen.dart';
import 'match_schedule_screen.dart';
import 'squad_screen.dart';
import 'tactics_screen.dart';
import 'transfer_market_screen.dart';
import 'admin/admin_panel_screen.dart';

class RootShell extends StatefulWidget {
  RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _ShellPage {
  final Widget page;
  final Widget icon;
  final String label;

  const _ShellPage({
    required this.page,
    required this.icon,
    required this.label,
  });
}

Widget _navIcon(String asset) => Image.asset(asset, width: 26, height: 26);

class _RootShellState extends State<RootShell> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Wire notification service to show UI SnackBars
    NotificationService.instance.onSendNotification = (title, body) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title: $body')),
      );
    };
  }

  @override
  void dispose() {
    // Clear callback
    NotificationService.instance.onSendNotification = null;
    super.dispose();
  }

  static List<_ShellPage> get _navigationPages => <_ShellPage>[
    _ShellPage(
      page: const DashboardScreen(),
      icon: const Icon(Icons.shield),
      label: 'navigation.club'.tr(),
    ),
    _ShellPage(
      page: ClubFinanceScreen(),
      icon: const Icon(Icons.account_balance_wallet),
      label: 'navigation.finance'.tr(),
    ),
    _ShellPage(
      page: SquadScreen(),
      icon: _navIcon(AppAssets.navSquad),
      label: 'navigation.squad'.tr(),
    ),
    _ShellPage(
      page: TacticsScreen(),
      icon: _navIcon(AppAssets.navTactics),
      label: 'navigation.tactics'.tr(),
    ),
    _ShellPage(
      page: TransferMarketScreen(),
      icon: _navIcon(AppAssets.navTransfer),
      label: 'navigation.transfer'.tr(),
    ),
    _ShellPage(
      page: MatchScheduleScreen(),
      icon: const Icon(Icons.calendar_month),
      label: 'navigation.calendar'.tr(),
    ),
    _ShellPage(
      page: LeagueTableScreen(),
      icon: _navIcon(AppAssets.navLeague),
      label: 'navigation.table'.tr(),
    ),
    _ShellPage(
      page: InboxScreen(),
      icon: const Icon(Icons.inbox),
      label: 'navigation.inbox'.tr(),
    ),
  ];

  void _onItemTapped(int index, {required bool hasActiveClub}) {
    if (index == 4 && !hasActiveClub) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('navigation.transfer_required'.tr()),
        ),
      );
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  AuthService? _authService;
  AuthService get _resolvedAuthService => _authService ??= AuthService();

  Future<void> _signOut() async {
    await _resolvedAuthService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/auth');
  }

  @override
  Widget build(BuildContext context) {
    final activeClub = context.select((GameProvider provider) => provider.activeClub);
    final isAdmin = context.select((GameProvider p) => p.isAdmin);
    final title = activeClub == null ? 'navigation.manager_panel'.tr() : 'navigation.club_prefix'.tr(namedArgs: {'name': activeClub.name});

    final pages = List<_ShellPage>.from(_navigationPages);
    if (isAdmin) {
      pages.add(_ShellPage(page: const AdminPanelScreen(), icon: const Icon(Icons.admin_panel_settings), label: 'Yönetici'));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
            tooltip: 'navigation.settings_tooltip'.tr(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'navigation.logout_tooltip'.tr(),
          )
        ],
      ),
      body: pages[_selectedIndex].page,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) => _onItemTapped(
          index,
          hasActiveClub: activeClub != null,
        ),
        items: List<BottomNavigationBarItem>.generate(
          pages.length,
          (index) {
            final page = pages[index];
            if (index == 7) {
              return BottomNavigationBarItem(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    page.icon,
                    if (context.watch<GameProvider>().unreadInboxCount > 0)
                      Positioned(
                        right: -6,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${context.watch<GameProvider>().unreadInboxCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                label: page.label,
              );
            }

            return BottomNavigationBarItem(
              icon: page.icon,
              label: page.label,
            );
          },
        ),
      ),
    );
  }
}
