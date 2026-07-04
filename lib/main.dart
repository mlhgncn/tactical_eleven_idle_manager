import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/game_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/root_shell.dart';
import 'screens/settings_screen.dart';
import 'services/admob_service.dart';
import 'services/analytics_service.dart';
import 'services/notification_service.dart';
import 'services/purchase_service.dart';

const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://dfdidifutotlxvvslzrl.supabase.co',
);
const supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'sb_publishable_edRyGD2ARwvI4q8pLyrFTg_G3cMdz5R',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await Firebase.initializeApp();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  await PurchaseService.instance.initialize();
  await AdMobService.instance.initialize();
  await AnalyticsService.instance.initialize();
  await NotificationService.instance.initialize();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: const SoccerManagerApp(),
    ),
  );
}

class SoccerManagerApp extends StatelessWidget {
  const SoccerManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final initialRoute = currentUser == null ? '/auth' : '/root';

    return ChangeNotifierProvider(
      create: (_) => GameProvider()..refreshGameState(),
      child: MaterialApp(
        title: 'Tactical Eleven: Idle Manager',
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        theme: ThemeData.dark().copyWith(
          colorScheme: ThemeData.dark().colorScheme.copyWith(primary: Colors.greenAccent),
          scaffoldBackgroundColor: const Color(0xFF101820),
        ),
        initialRoute: initialRoute,
        routes: {
          '/auth': (_) => const AuthScreen(),
          '/root': (_) => const RootShell(),
          '/settings': (_) => const SettingsScreen(),
        },
      ),
    );
  }
}
