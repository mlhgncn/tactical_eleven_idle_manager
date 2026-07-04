import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'providers/game_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/email_verification_screen.dart';
import 'screens/root_shell.dart';
import 'screens/setup_club_screen.dart';
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
  await Firebase.initializeApp(
    options: Config.firebaseConfigured ? Config.firebaseOptions : null,
  );

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
  const SoccerManagerApp({super.key, this.gameProvider, this.initialHome});

  final GameProvider? gameProvider;
  final Widget? initialHome;

  @override
  Widget build(BuildContext context) {
    final delegates = EasyLocalization.of(context)?.delegates ?? <LocalizationsDelegate>[
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ];
    final supportedLocales = EasyLocalization.of(context)?.supportedLocales ?? const [Locale('tr'), Locale('en')];
    final locale = EasyLocalization.of(context)?.locale ?? const Locale('tr');

    return ChangeNotifierProvider<GameProvider>(
      create: (_) => gameProvider ?? GameProvider()..refreshGameState(),
      child: MaterialApp(
        title: 'Tactical Eleven: Idle Manager',
        localizationsDelegates: delegates,
        supportedLocales: supportedLocales,
        locale: locale,
        theme: ThemeData.dark().copyWith(
          colorScheme: ThemeData.dark().colorScheme.copyWith(primary: Colors.greenAccent),
          scaffoldBackgroundColor: const Color(0xFF101820),
        ),
        home: initialHome ?? const AuthGate(),
        routes: {
          '/auth': (_) => const AuthScreen(),
          '/email-verification': (_) => const EmailVerificationScreen(),
          '/setup-club': (_) => const SetupClubScreen(),
          '/root': (_) => const RootShell(),
          '/settings': (_) => const SettingsScreen(),
        },
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _lastUserId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? Supabase.instance.client.auth.currentSession;
        final userId = session?.user.id;

        if (userId != null && userId != _lastUserId) {
          _lastUserId = userId;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.read<GameProvider>().refreshGameState();
            }
          });
        }

        final provider = context.watch<GameProvider>();

        if (snapshot.connectionState == ConnectionState.waiting || provider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (session == null) {
          return const AuthScreen();
        }

        if (provider.activeClub == null) {
          return const SetupClubScreen();
        }

        return const RootShell();
      },
    );
  }
}
