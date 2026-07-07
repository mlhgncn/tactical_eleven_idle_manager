import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

import '../repositories/supabase_repository.dart';

// Local-only for now: push notifications need a real FCM/APNs backend
// (firebase_messaging pulled in an unconfigured Firebase native pod that
// caused an instant launch crash - see analytics_service.dart). Re-add
// firebase_messaging once real Firebase credentials exist.
class NotificationService {
  NotificationService._({SupabaseRepository? repository}) : _repository = repository;

  static final NotificationService instance = NotificationService._();

  final SupabaseRepository? _repository;

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  bool _enabled = true;

  SupabaseRepository get _resolvedRepository => _repository ?? SupabaseRepository();

  void Function(String title, String body)? onSendNotification;

  bool get enabled => _enabled;

  Future<void> initialize() async {
    try {
      // Initialize local notifications
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      await _local.initialize(
        settings: const InitializationSettings(android: androidInit, iOS: iosInit),
        onDidReceiveNotificationResponse: (response) async {
          // Handle local notification tap
        },
      );

      // Load persisted preference from server if available
      final pref = await _resolvedRepository.loadNotificationPreference();
      if (pref != null) _enabled = pref;
    } catch (e) {
      debugPrint('NotificationService.initialize error: $e');
    }
  }

  Future<void> _showLocalNotification(String title, String body, Map<String, dynamic>? data) async {
    final androidDetails = AndroidNotificationDetails(
      'default_channel',
      'General',
      channelDescription: 'General notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    final iosDetails = DarwinNotificationDetails();
    await _local.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: data != null ? jsonEncode(data) : null,
    );
  }

  Future<void> sendNotification(String title, String body) async {
    if (!_enabled) return;
    if (onSendNotification != null) {
      onSendNotification!(title, body);
      return;
    }
    await _showLocalNotification(title, body, null);
  }

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    try {
      await _resolvedRepository.updateNotificationPreference(enabled);
    } catch (_) {}
  }
}
