import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/game_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/root_shell.dart';

const supabaseUrl = 'YOUR_SUPABASE_URL';
const supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

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

    return EasyLocalizationProvider(
      child: ChangeNotifierProvider(
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
      ),
    );
  }
}
