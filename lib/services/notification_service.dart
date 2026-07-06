import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

import '../repositories/supabase_repository.dart';

class NotificationService {
  NotificationService._({FirebaseMessaging? messaging, SupabaseRepository? repository})
      : _messaging = messaging,
        _repository = repository;

  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging? _messaging;
  final SupabaseRepository? _repository;

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  bool _enabled = true;

  FirebaseMessaging get _resolvedMessaging => _messaging ?? FirebaseMessaging.instance;
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

      // Request permission for notifications
      final settings = await _resolvedMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        final token = await _resolvedMessaging.getToken();
        if (token != null) {
          await _resolvedRepository.updateFcmToken(token);
        }

        _resolvedMessaging.onTokenRefresh.listen((newToken) async {
          await _resolvedRepository.updateFcmToken(newToken);
        });

        // Foreground message handling to show local notifications
        FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
          if (!_enabled) return;
          final notification = message.notification;
          final title = notification?.title ?? 'Bildirim';
          final body = notification?.body ?? '';
          await _showLocalNotification(title, body, message.data);
        });

        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          // Optionally handle notification taps
        });
      }

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
