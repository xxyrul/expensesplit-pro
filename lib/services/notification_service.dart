import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'budget_alerts';
  static const _channelName = 'Budget Alerts';
  static const _channelDesc =
      'Alerts when your monthly spending approaches the budget limit.';
  static const _notificationId = 42;
  static const _systemBroadcastNotificationId = 43;

  int _notificationIdForCategory(String category) {
    final categoryHash = category.hashCode.abs();
    return _notificationId + (categoryHash % 1000000) + 1;
  }

  Future<void> initialize() async {
    // Android setup
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS setup
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);

    // Request Android 13+ permission
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
  }

  Future<void> showBudgetWarning(double limit) async {
    final formattedLimit = limit.toStringAsFixed(0);
    await _showNotification(
      id: _notificationId,
      title: 'Monthly budget is running low',
      body:
          'You have used 80% of your RM $formattedLimit monthly budget. Consider reviewing your spending.',
    );
  }

  Future<void> showCategoryBudgetWarning({
    required String category,
    required double limit,
  }) async {
    final formattedLimit = limit.toStringAsFixed(0);
    await _showNotification(
      id: _notificationIdForCategory(category),
      title: '$category budget is running low',
      body:
          'You have used 80% of your RM $formattedLimit $category budget. Consider reviewing this category.',
    );
  }

  Future<void> showSystemBroadcast({
    required String title,
    required String body,
  }) async {
    await _showNotification(
      id: _systemBroadcastNotificationId,
      title: title,
      body: body,
    );
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(id, title, body, details);
  }
}
