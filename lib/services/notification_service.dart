import 'package:firebase_messaging/firebase_messaging.dart';

import '../repositories/supabase_repository.dart';

class NotificationService {
  NotificationService._({FirebaseMessaging? messaging, SupabaseRepository? repository})
      : _messaging = messaging,
        _repository = repository;

  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging? _messaging;
  final SupabaseRepository? _repository;

  FirebaseMessaging get _resolvedMessaging => _messaging ?? FirebaseMessaging.instance;
  SupabaseRepository get _resolvedRepository => _repository ?? SupabaseRepository();

  void Function(String title, String body)? onSendNotification;

  Future<void> initialize() async {
    await _resolvedMessaging.requestPermission();
    final token = await _resolvedMessaging.getToken();
    if (token != null) {
      await _resolvedRepository.updateFcmToken(token);
    }

    _resolvedMessaging.onTokenRefresh.listen((newToken) async {
      await _resolvedRepository.updateFcmToken(newToken);
    });
  }

  Future<void> sendNotification(String title, String body) async {
    if (onSendNotification != null) {
      onSendNotification!(title, body);
      return;
    }

    // In production, this would dispatch a push notification or local alert.
  }
}
