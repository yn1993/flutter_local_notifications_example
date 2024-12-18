import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('app_icon'),
      iOS: DarwinInitializationSettings(),
    ),
  );
  runApp(
    const MaterialApp(
      home: HomePage(),
    ),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plugin example app'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Center(
            child: Column(
              children: <Widget>[
                ElevatedButton(
                    onPressed: _requestPermissions,
                    child: const Text('Request Permissions')),
                ElevatedButton(
                    onPressed: _showNotification,
                    child: const Text('Show Notification')),
                ElevatedButton(
                    onPressed: _showNotificationCustomSound,
                    child: const Text('Show Notification with Custom Sound')),
                ElevatedButton(
                    onPressed: _showNotificationCustomSound_2,
                    child: const Text('Show Notification with Custom Sound_2')),
                ElevatedButton(
                    onPressed: _showNotificationCustomSound_3,
                    child: const Text('Show Notification with Custom Sound_3')),
                ElevatedButton(
                    onPressed: _triggerVibration,
                    child: const Text('Trigger Vibration'))
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _generateRandomId() {
    return Random().nextInt(1000000);
  }

  Future<void> _showNotification({
    String title = 'plain title',
    String body = 'plain body',
  }) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('your channel id', 'your channel name',
            channelDescription: 'your channel description',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker');
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
      _generateRandomId(),
      title,
      body,
      notificationDetails,
    );
  }

  Future<void> _showNotificationCustomSound({
    String title = 'custom sound notification title',
    String body = 'custom sound notification body',
  }) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'your other channel id',
      'your other channel name',
      channelDescription: 'your other channel description',
      sound: RawResourceAndroidNotificationSound('slow_spring_board'),
    );
    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
      sound: 'slow_spring_board.aiff',
    );
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: darwinNotificationDetails,
      macOS: darwinNotificationDetails,
    );
    await flutterLocalNotificationsPlugin.show(
      _generateRandomId(),
      title,
      body,
      notificationDetails,
    );
  }

  Future<void> _showNotificationCustomSound_2({
    String title = 'custom sound notification title',
    String body = 'custom sound notification body',
  }) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'your other channel id',
      'your other channel name',
      channelDescription: 'your other channel description',
      sound: RawResourceAndroidNotificationSound('Telephone-Ringtone02-1'),
    );
    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
      sound: 'Telephone-Ringtone02-1.aiff',
    );
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: darwinNotificationDetails,
      macOS: darwinNotificationDetails,
    );
    await flutterLocalNotificationsPlugin.show(
      _generateRandomId(),
      title,
      body,
      notificationDetails,
    );
  }

  Future<void> _showNotificationCustomSound_3({
    String title = 'custom sound notification title',
    String body = 'custom sound notification body',
  }) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'your other channel id',
      'your other channel name',
      channelDescription: 'your other channel description',
      sound: RawResourceAndroidNotificationSound('Telephone-Ringtone02-1-big'),
    );
    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
      sound: 'Telephone-Ringtone02-1-big.aiff',
    );
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: darwinNotificationDetails,
      macOS: darwinNotificationDetails,
    );
    await flutterLocalNotificationsPlugin.show(
      _generateRandomId(),
      title,
      body,
      notificationDetails,
    );
  }

  void _triggerVibration() {
    HapticFeedback.vibrate(); // 振動を発生させる
  }
}
