import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/game_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/email_verification_screen.dart';
import 'screens/root_shell.dart';
import 'screens/settings_screen.dart';
import 'screens/setup_club_screen.dart';
import 'services/error_reporting_service.dart';
import 'services/analytics_service.dart';
import 'config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Every screen/service in this app reaches Supabase via
  // `Supabase.instance.client`, which throws synchronously if the SDK was
  // never initialized. AuthScreen builds an AuthService() (and therefore
  // touches Supabase.instance) as soon as it's constructed, so without this
  // call the app crashes on the very first frame - before any UI, before
  // Crashlytics is even set up. This must run before runApp.
  if (Config.supabaseConfigured) {
    await Supabase.initialize(
      url: Config.supabaseUrl,
      anonKey: Config.supabaseAnonKey,
    );
  }

  // Route Flutter errors to our reporter (currently logs; swap in a real
  // crash-reporting backend here once one is configured).
  FlutterError.onError = (details) {
    ErrorReportingService.report(details.exception, details.stack, reason: 'FlutterError');
  };
  await AnalyticsService.instance.initialize();

  runZonedGuarded(() {
    runApp(
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('tr')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        child: const MyApp(),
      ),
    );
  }, (error, stack) async {
    await ErrorReportingService.report(error, stack, reason: 'Uncaught');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // If Supabase env vars weren't baked in at build time, every screen
    // would crash the moment it touches Supabase.instance anyway - show a
    // clear message instead of an opaque native crash with no context.
    if (!Config.supabaseConfigured) {
      return MaterialApp(
        title: 'app.title'.tr(),
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: const _ConfigErrorScreen(),
      );
    }

    // GameProvider must live above the navigator so every route (auth,
    // club setup, root shell, settings...) shares the same instance -
    // screens reach it via context.watch/read<GameProvider>(), which
    // throws ProviderNotFoundException if it isn't provided somewhere
    // above them in the tree.
    return ChangeNotifierProvider<GameProvider>(
      create: (_) => GameProvider(),
      child: MaterialApp(
        title: 'app.title'.tr(),
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        ),
        initialRoute: '/auth',
        routes: {
          '/auth': (_) => AuthScreen(),
          '/email-verification': (_) => const EmailVerificationScreen(),
          '/setup-club': (_) => SetupClubScreen(),
          '/root': (_) => RootShell(),
          '/settings': (_) => const SettingsScreen(),
        },
      ),
    );
  }
}

class _ConfigErrorScreen extends StatelessWidget {
  const _ConfigErrorScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'This build is missing its Supabase configuration '
                  '(SUPABASE_URL / SUPABASE_ANON_KEY) and cannot connect to the server.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
