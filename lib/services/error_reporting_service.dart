typedef ErrorReporter = Future<void> Function(Object error, StackTrace? stack, {String? reason});

class ErrorReportingService {
  // Default reporter logs to console. Replace at app startup with Crashlytics.
  static ErrorReporter reporter = (error, stack, {reason}) async {
    // Keep minimal: print so devs can see when not configured
    // Avoid throwing from reporter
    try {
      print('REPORT ERROR: ${error.toString()}');
      if (stack != null) print(stack.toString());
    } catch (_) {}
  };

  static Future<void> report(Object error, StackTrace? stack, {String? reason}) async {
    await reporter(error, stack, reason: reason);
  }
}

// Usage example (in `main.dart`) to forward errors to Firebase Crashlytics:
//
// import 'package:firebase_crashlytics/firebase_crashlytics.dart';
// ErrorReportingService.reporter = (error, stack, {reason}) async {
//   await FirebaseCrashlytics.instance.recordError(error, stack, reason: reason);
// };

