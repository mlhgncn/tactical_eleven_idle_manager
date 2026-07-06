import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  Future<void> initialize() async {
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

      FlutterError.onError = (FlutterErrorDetails errorDetails) {
        // Record non-fatal Flutter framework errors to Crashlytics
        FirebaseCrashlytics.instance.recordFlutterError(errorDetails);
      };

      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        // Record errors caught by the platform dispatcher as non-fatal
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: false);
        return true; // Prevent the error from causing the app to crash
      };
    } catch (e, st) {
      // If Crashlytics initialization fails, print but don't rethrow.
      // Avoid crashing the app due to analytics/crash reporting failures.
      debugPrint('AnalyticsService.initialize error: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    await analytics.logEvent(name: name, parameters: parameters);
  }
}
