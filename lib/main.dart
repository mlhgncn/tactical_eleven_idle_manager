import 'dart:async';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/game_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/email_verification_screen.dart';
import 'screens/league_selector_screen.dart';
import 'screens/root_shell.dart';
import 'screens/settings_screen.dart';
import 'screens/setup_club_screen.dart';
import 'services/ad_service.dart';
import 'services/error_reporting_service.dart';
import 'services/analytics_service.dart';
import 'config.dart';
import 'theme/app_theme.dart';

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

/// Requests the ATT permission dialog and then initializes AdMob (which
/// reads the IDFA and must not run before the user has answered). Must be
/// called AFTER the first frame is on screen - iOS's system permission
/// sheet needs an actual foreground window to attach to, and calling this
/// from main() before runApp() (the previous approach) meant there was no
/// window yet, so the dialog would intermittently never appear at all.
/// This is exactly what an App Store reviewer hit: the app launched but no
/// ATT prompt showed up during their review.
Future<void> _requestTrackingAndInitAds() async {
  if (Platform.isIOS) {
    if (await AppTrackingTransparency.trackingAuthorizationStatus == TrackingStatus.notDetermined) {
      await AppTrackingTransparency.requestTrackingAuthorization();
    }
  }
  unawaited(AdService.instance.initialize());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Fires after this first frame is actually on screen, which is what
    // the ATT permission sheet needs to attach to - see
    // _requestTrackingAndInitAds's doc comment for why this can't run
    // earlier (e.g. in main() before runApp()).
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestTrackingAndInitAds());
  }

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
        theme: AppTheme.dark,
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
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        initialRoute: '/auth',
        routes: {
          '/auth': (_) => AuthScreen(),
          '/login': (_) => LoginScreen(),
          '/email-verification': (_) => const EmailVerificationScreen(),
          '/setup-club': (_) => SetupClubScreen(),
          '/league-selector': (_) => const LeagueSelectorScreen(),
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
