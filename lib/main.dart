import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'screens/auth_screen.dart';
import 'services/error_reporting_service.dart';
import 'services/analytics_service.dart';
import 'config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Initialize Firebase & Crashlytics if configured, and wire error reporting.
  if (Config.firebaseConfigured) {
    await Firebase.initializeApp(options: Config.firebaseOptions);
    // Enable Crashlytics collection and set reporter
    ErrorReportingService.reporter = (error, stack, {reason}) async {
      try {
        await FirebaseCrashlytics.instance.recordError(error, stack, reason: reason, fatal: false);
      } catch (_) {
        // swallow to avoid infinite loops
      }
    };
    // Initialize analytics/crashlytics handlers
    await AnalyticsService.instance.initialize();
  } else {
    // Default: route Flutter errors to our reporter which currently logs
    FlutterError.onError = (details) {
      ErrorReportingService.report(details.exception, details.stack, reason: 'FlutterError');
    };
  }

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
    return MaterialApp(
      title: 'app.title'.tr(),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: AuthScreen(),
    );
  }
}
