import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel downloadChannel = AndroidNotificationChannel(
  'download_channel',
  'Downloads',
  description: 'Download status notifications',
  importance: Importance.defaultImportance,
);

Future<void> initializeNotifications() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const settings = InitializationSettings(android: androidSettings);

  await flutterLocalNotificationsPlugin.initialize(settings);

  final androidPlugin =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  await androidPlugin?.createNotificationChannel(downloadChannel);
}
