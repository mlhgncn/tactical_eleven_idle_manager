import 'package:firebase_messaging/firebase_messaging.dart';

import '../repositories/supabase_repository.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final SupabaseRepository _repository = SupabaseRepository();

  Future<void> initialize() async {
    await _messaging.requestPermission();
    final token = await _messaging.getToken();
    if (token != null) {
      await _repository.updateFcmToken(token);
    }

    _messaging.onTokenRefresh.listen((newToken) async {
      await _repository.updateFcmToken(newToken);
    });
  }
}
