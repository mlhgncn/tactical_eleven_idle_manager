import 'package:flutter/foundation.dart';

// Local stand-in until a real analytics/crash-reporting backend is wired up.
// Deliberately has no native SDK dependency: an unconfigured Firebase
// Analytics/Crashlytics native pod was the root cause of an instant,
// screen-less launch crash (FirebaseSessions aborts if FirebaseApp was never
// configured), so this stays pure-Dart until real credentials exist.
class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  Future<void> initialize() async {
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      debugPrint('Unhandled error: $error\n$stack');
      return true;
    };
  }

  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    debugPrint('ANALYTICS EVENT: $name ${parameters ?? {}}');
  }
}
