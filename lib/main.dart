import 'dart:async';
import 'dart:convert';
import 'dart:io';
// ignore: unnecessary_import
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

int id = 0;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Streams are created so that app can respond to notification-related events
/// since the plugin is initialised in the `main` function
final StreamController<ReceivedNotification> didReceiveLocalNotificationStream =
    StreamController<ReceivedNotification>.broadcast();

final StreamController<String?> selectNotificationStream =
    StreamController<String?>.broadcast();

const MethodChannel platform =
    MethodChannel('dexterx.dev/flutter_local_notifications_example');

const String portName = 'notification_send_port';

class ReceivedNotification {
  ReceivedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final String? title;
  final String? body;
  final String? payload;
}

String? selectedNotificationPayload;

/// A notification action which triggers a url launch event
const String urlLaunchActionId = 'id_1';

/// A notification action which triggers a App navigation event
const String navigationActionId = 'id_3';

/// Defines a iOS/MacOS notification category for text input actions.
const String darwinNotificationCategoryText = 'textCategory';

/// Defines a iOS/MacOS notification category for plain actions.
const String darwinNotificationCategoryPlain = 'plainCategory';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // ignore: avoid_print
  print('notification(${notificationResponse.id}) action tapped: '
      '${notificationResponse.actionId} with'
      ' payload: ${notificationResponse.payload}');
  if (notificationResponse.input?.isNotEmpty ?? false) {
    // ignore: avoid_print
    print(
        'notification action tapped with input: ${notificationResponse.input}');
  }
}

/// IMPORTANT: running the following code on its own won't work as there is
/// setup required for each platform head project.
///
/// Please download the complete example app from the GitHub repository where
/// all the setup has been done
Future<void> main() async {
  // needed if you intend to initialize in the `main` function
  WidgetsFlutterBinding.ensureInitialized();

  final NotificationAppLaunchDetails? notificationAppLaunchDetails = !kIsWeb &&
          Platform.isLinux
      ? null
      : await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
  String initialRoute = HomePage.routeName;
  if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
    selectedNotificationPayload =
        notificationAppLaunchDetails!.notificationResponse?.payload;
    initialRoute = SecondPage.routeName;
  }

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('app_icon');

  final List<DarwinNotificationCategory> darwinNotificationCategories =
      <DarwinNotificationCategory>[
    DarwinNotificationCategory(
      darwinNotificationCategoryText,
      actions: <DarwinNotificationAction>[
        DarwinNotificationAction.text(
          'text_1',
          'Action 1',
          buttonTitle: 'Send',
          placeholder: 'Placeholder',
        ),
      ],
    ),
    DarwinNotificationCategory(
      darwinNotificationCategoryPlain,
      actions: <DarwinNotificationAction>[
        DarwinNotificationAction.plain('id_1', 'Action 1'),
        DarwinNotificationAction.plain(
          'id_2',
          'Action 2 (destructive)',
          options: <DarwinNotificationActionOption>{
            DarwinNotificationActionOption.destructive,
          },
        ),
        DarwinNotificationAction.plain(
          navigationActionId,
          'Action 3 (foreground)',
          options: <DarwinNotificationActionOption>{
            DarwinNotificationActionOption.foreground,
          },
        ),
        DarwinNotificationAction.plain(
          'id_4',
          'Action 4 (auth required)',
          options: <DarwinNotificationActionOption>{
            DarwinNotificationActionOption.authenticationRequired,
          },
        ),
      ],
      options: <DarwinNotificationCategoryOption>{
        DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
      },
    )
  ];

  /// Note: permissions aren't requested here just to demonstrate that can be
  /// done later
  final DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
    onDidReceiveLocalNotification:
        (int id, String? title, String? body, String? payload) async {
      didReceiveLocalNotificationStream.add(
        ReceivedNotification(
          id: id,
          title: title,
          body: body,
          payload: payload,
        ),
      );
    },
    notificationCategories: darwinNotificationCategories,
  );
  final LinuxInitializationSettings initializationSettingsLinux =
      LinuxInitializationSettings(
    defaultActionName: 'Open notification',
    defaultIcon: AssetsLinuxIcon('icons/app_icon.png'),
  );
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
    macOS: initializationSettingsDarwin,
    linux: initializationSettingsLinux,
  );
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse:
        (NotificationResponse notificationResponse) {
      switch (notificationResponse.notificationResponseType) {
        case NotificationResponseType.selectedNotification:
          selectNotificationStream.add(notificationResponse.payload);
          break;
        case NotificationResponseType.selectedNotificationAction:
          if (notificationResponse.actionId == navigationActionId) {
            selectNotificationStream.add(notificationResponse.payload);
          }
          break;
      }
    },
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );
  runApp(
    MaterialApp(
      initialRoute: initialRoute,
      routes: <String, WidgetBuilder>{
        HomePage.routeName: (_) => HomePage(notificationAppLaunchDetails),
        SecondPage.routeName: (_) => SecondPage(selectedNotificationPayload)
      },
    ),
  );
}

class PaddedElevatedButton extends StatelessWidget {
  const PaddedElevatedButton({
    required this.buttonText,
    required this.onPressed,
    Key? key,
  }) : super(key: key);

  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
        child: ElevatedButton(
          onPressed: onPressed,
          child: Text(buttonText),
        ),
      );
}

class HomePage extends StatefulWidget {
  const HomePage(
    this.notificationAppLaunchDetails, {
    Key? key,
  }) : super(key: key);

  static const String routeName = '/';

  final NotificationAppLaunchDetails? notificationAppLaunchDetails;

  bool get didNotificationLaunchApp =>
      notificationAppLaunchDetails?.didNotificationLaunchApp ?? false;

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _linuxIconPathController =
      TextEditingController();

  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _isAndroidPermissionGranted();
    _requestPermissions();
    _configureDidReceiveLocalNotificationSubject();
    _configureSelectNotificationSubject();
  }

  Future<void> _isAndroidPermissionGranted() async {
    if (Platform.isAndroid) {
      final bool granted = await flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled() ??
          false;

      setState(() {
        _notificationsEnabled = granted;
      });
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isIOS || Platform.isMacOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final bool? grantedNotificationPermission =
          await androidImplementation?.requestNotificationsPermission();
      setState(() {
        _notificationsEnabled = grantedNotificationPermission ?? false;
      });
    }
  }

  void _configureDidReceiveLocalNotificationSubject() {
    didReceiveLocalNotificationStream.stream
        .listen((ReceivedNotification receivedNotification) async {
      await showDialog(
        context: context,
        builder: (BuildContext context) => CupertinoAlertDialog(
          title: receivedNotification.title != null
              ? Text(receivedNotification.title!)
              : null,
          content: receivedNotification.body != null
              ? Text(receivedNotification.body!)
              : null,
          actions: <Widget>[
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () async {
                Navigator.of(context, rootNavigator: true).pop();
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) =>
                        SecondPage(receivedNotification.payload),
                  ),
                );
              },
              child: const Text('Ok'),
            )
          ],
        ),
      );
    });
  }

  void _configureSelectNotificationSubject() {
    selectNotificationStream.stream.listen((String? payload) async {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (BuildContext context) => SecondPage(payload),
      ));
    });
  }

  @override
  void dispose() {
    didReceiveLocalNotificationStream.close();
    selectNotificationStream.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Center(
              child: Column(
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(0, 0, 0, 8),
                    child:
                        Text('Tap on a notification when it appears to trigger'
                            ' navigation'),
                  ),
                  _InfoValueString(
                    title: 'Did notification launch app?',
                    value: widget.didNotificationLaunchApp,
                  ),
                  if (widget.didNotificationLaunchApp) ...<Widget>[
                    const Text('Launch notification details'),
                    _InfoValueString(
                        title: 'Notification id',
                        value: widget.notificationAppLaunchDetails!
                            .notificationResponse?.id),
                    _InfoValueString(
                        title: 'Action id',
                        value: widget.notificationAppLaunchDetails!
                            .notificationResponse?.actionId),
                    _InfoValueString(
                        title: 'Input',
                        value: widget.notificationAppLaunchDetails!
                            .notificationResponse?.input),
                    _InfoValueString(
                      title: 'Payload:',
                      value: widget.notificationAppLaunchDetails!
                          .notificationResponse?.payload,
                    ),
                  ],
                  PaddedElevatedButton(
                    buttonText: 'Show plain notification with payload',
                    onPressed: () async {
                      await _showNotification();
                    },
                  ),
                  PaddedElevatedButton(
                    buttonText:
                        'Show plain notification that has no title with '
                        'payload',
                    onPressed: () async {
                      await _showNotificationWithNoTitle();
                    },
                  ),
                  PaddedElevatedButton(
                    buttonText: 'Show plain notification that has no body with '
                        'payload',
                    onPressed: () async {
                      await _showNotificationWithNoBody();
                    },
                  ),
                  PaddedElevatedButton(
                    buttonText: 'Show notification with custom sound',
                    onPressed: () async {
                      await _showNotificationCustomSound();
                    },
                  ),
                  const Divider(),
                  if (Platform.isAndroid) ...<Widget>[
                    const Text(
                      'Android-specific examples',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('notifications enabled: $_notificationsEnabled'),
                    PaddedElevatedButton(
                      buttonText:
                          'Check if notifications are enabled for this app',
                      onPressed: _areNotifcationsEnabledOnAndroid,
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Request permission (API 33+)',
                      onPressed: () => _requestPermissions(),
                    ),
                    PaddedElevatedButton(
                      buttonText:
                          'Show plain notification with payload and update '
                          'channel description',
                      onPressed: () async {
                        await _showNotificationUpdateChannelDescription();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Show plain notification as public on every '
                          'lockscreen',
                      onPressed: () async {
                        await _showPublicNotification();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText:
                          'Show notification with custom vibration pattern, '
                          'red LED and red icon',
                      onPressed: () async {
                        await _showNotificationCustomVibrationIconLed();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Show notification using Android Uri sound',
                      onPressed: () async {
                        await _showSoundUriNotification();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText:
                          'Show notification that times out after 3 seconds',
                      onPressed: () async {
                        await _showTimeoutNotification();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Show insistent notification',
                      onPressed: () async {
                        await _showInsistentNotification();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Show big text notification',
                      onPressed: () async {
                        await _showBigTextNotification();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Show inbox notification',
                      onPressed: () async {
                        await _showInboxNotification();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Show grouped notifications',
                      onPressed: () async {
                        await _showGroupedNotifications();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Show notification with tag',
                      onPressed: () async {
                        await _showNotificationWithTag();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Cancel notification with tag',
                      onPressed: () async {
                        await _cancelNotificationWithTag();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Show ongoing notification',
                      onPressed: () async {
                        await _showOngoingNotification();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText:
                          'Show notification with no badge, alert only once',
                      onPressed: () async {
                        await _showNotificationWithNoBadge();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText:
                          'Show progress notification - updates every second',
                      onPressed: () async {
                        await _showProgressNotification();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Show indeterminate progress notification',
                      onPressed: () async {
                        await _showIndeterminateProgressNotification();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Show notification without timestamp',
                      onPressed: () async {
                        await _showNotificationWithoutTimestamp();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Show notification with custom timestamp',
                      onPressed: () async {
                        await _showNotificationWithCustomTimestamp();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Show notification with custom sub-text',
                      onPressed: () async {
                        await _showNotificationWithCustomSubText();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Show notification with chronometer',
                      onPressed: () async {
                        await _showNotificationWithChronometer();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText:
                          'Request full-screen intent permission (API 34+)',
                      onPressed: () async {
                        await _requestFullScreenIntentPermission();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Show full-screen notification',
                      onPressed: () async {
                        await _showFullScreenNotification();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText:
                          'Show notification with number if the launcher '
                          'supports',
                      onPressed: () async {
                        await _showNotificationWithNumber();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Show notification with sound controlled by '
                          'alarm volume',
                      onPressed: () async {
                        await _showNotificationWithAudioAttributeAlarm();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Create grouped notification channels',
                      onPressed: () async {
                        await _createNotificationChannelGroup();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Delete notification channel group',
                      onPressed: () async {
                        await _deleteNotificationChannelGroup();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Create notification channel',
                      onPressed: () async {
                        await _createNotificationChannel();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Delete notification channel',
                      onPressed: () async {
                        await _deleteNotificationChannel();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Get notification channels',
                      onPressed: () async {
                        await _getNotificationChannels();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Start foreground service',
                      onPressed: () async {
                        await _startForegroundService();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText:
                          'Start foreground service with blue background '
                          'notification',
                      onPressed: () async {
                        await _startForegroundServiceWithBlueBackgroundNotification();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Stop foreground service',
                      onPressed: () async {
                        await _stopForegroundService();
                      },
                    ),
                  ],
                  if (!kIsWeb &&
                      (Platform.isIOS || Platform.isMacOS)) ...<Widget>[
                    const Text(
                      'iOS and macOS-specific examples',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Check permissions',
                      onPressed: _checkNotificationsOnCupertino,
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Request permission',
                      onPressed: _requestPermissions,
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Show notification with subtitle',
                      onPressed: () async {
                        await _showNotificationWithSubtitle();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Show notification with icon badge',
                      onPressed: () async {
                        await _showNotificationWithIconBadge();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Show notifications with thread identifier',
                      onPressed: () async {
                        await _showNotificationsWithThreadIdentifier();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText:
                          'Show notification with time sensitive interruption '
                          'level',
                      onPressed: () async {
                        await _showNotificationWithTimeSensitiveInterruptionLevel();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Show notification with banner but not in '
                          'notification centre',
                      onPressed: () async {
                        await _showNotificationWithBannerNotInNotificationCentre();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText:
                          'Show notification in notification centre only',
                      onPressed: () async {
                        await _showNotificationInNotificationCentreOnly();
                      },
                    ),
                  ],
                  if (!kIsWeb && Platform.isLinux) ...<Widget>[
                    const Text(
                      'Linux-specific examples',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    FutureBuilder<LinuxServerCapabilities>(
                      future: getLinuxCapabilities(),
                      builder: (
                        BuildContext context,
                        AsyncSnapshot<LinuxServerCapabilities> snapshot,
                      ) {
                        if (snapshot.hasData) {
                          final LinuxServerCapabilities caps = snapshot.data!;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Capabilities of the current system:',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium!
                                      .copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                _InfoValueString(
                                  title: 'Body text:',
                                  value: caps.body,
                                ),
                                _InfoValueString(
                                  title: 'Hyperlinks in body text:',
                                  value: caps.bodyHyperlinks,
                                ),
                                _InfoValueString(
                                  title: 'Images in body:',
                                  value: caps.bodyImages,
                                ),
                                _InfoValueString(
                                  title: 'Markup in the body text:',
                                  value: caps.bodyMarkup,
                                ),
                                _InfoValueString(
                                  title: 'Animated icons:',
                                  value: caps.iconMulti,
                                ),
                                _InfoValueString(
                                  title: 'Static icons:',
                                  value: caps.iconStatic,
                                ),
                                _InfoValueString(
                                  title: 'Notification persistence:',
                                  value: caps.persistence,
                                ),
                                _InfoValueString(
                                  title: 'Sound:',
                                  value: caps.sound,
                                ),
                                _InfoValueString(
                                  title: 'Actions:',
                                  value: caps.actions,
                                ),
                                _InfoValueString(
                                  title: 'Action icons:',
                                  value: caps.actionIcons,
                                ),
                                _InfoValueString(
                                  title: 'Other capabilities:',
                                  value: caps.otherCapabilities,
                                ),
                              ],
                            ),
                          );
                        } else {
                          return const CircularProgressIndicator();
                        }
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Show notification with body markup',
                      onPressed: () async {
                        await _showLinuxNotificationWithBodyMarkup();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Show notification with category',
                      onPressed: () async {
                        await _showLinuxNotificationWithCategory();
                      },
                    ),
                    Builder(
                      builder: (BuildContext context) => PaddedElevatedButton(
                        buttonText: 'Show notification with file path icon',
                        onPressed: () async {
                          final String path = _linuxIconPathController.text;
                          if (path.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter the icon path'),
                              ),
                            );
                            return;
                          }
                          await _showLinuxNotificationWithPathIcon(path);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                      child: TextField(
                        controller: _linuxIconPathController,
                        decoration: InputDecoration(
                          hintText: 'Enter the icon path',
                          constraints: const BoxConstraints.tightFor(
                            width: 300,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _linuxIconPathController.clear(),
                          ),
                        ),
                      ),
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Show notification with theme icon',
                      onPressed: () async {
                        await _showLinuxNotificationWithThemeIcon();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Show notification with theme sound',
                      onPressed: () async {
                        await _showLinuxNotificationWithThemeSound();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Show notification with critical urgency',
                      onPressed: () async {
                        await _showLinuxNotificationWithCriticalUrgency();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Show notification with timeout',
                      onPressed: () async {
                        await _showLinuxNotificationWithTimeout();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Suppress notification sound',
                      onPressed: () async {
                        await _showLinuxNotificationSuppressSound();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Transient notification',
                      onPressed: () async {
                        await _showLinuxNotificationTransient();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Resident notification',
                      onPressed: () async {
                        await _showLinuxNotificationResident();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Show notification on '
                          'different screen location',
                      onPressed: () async {
                        await _showLinuxNotificationDifferentLocation();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );

  Future<void> _showNotification() async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('your channel id', 'your channel name',
            channelDescription: 'your channel description',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker');
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
        id++, 'plain title', 'plain body', notificationDetails,
        payload: 'item x');
  }

  Future<void> _showNotificationWithActions() async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'your channel id',
      'your channel name',
      channelDescription: 'your channel description',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          urlLaunchActionId,
          'Action 1',
          icon: DrawableResourceAndroidBitmap('food'),
          contextual: true,
        ),
        AndroidNotificationAction(
          'id_2',
          'Action 2',
          titleColor: Color.fromARGB(255, 255, 0, 0),
          icon: DrawableResourceAndroidBitmap('secondary_icon'),
        ),
        AndroidNotificationAction(
          navigationActionId,
          'Action 3',
          icon: DrawableResourceAndroidBitmap('secondary_icon'),
          showsUserInterface: true,
          // By default, Android plugin will dismiss the notification when the
          // user tapped on a action (this mimics the behavior on iOS).
          cancelNotification: false,
        ),
      ],
    );

    const DarwinNotificationDetails iosNotificationDetails =
        DarwinNotificationDetails(
      categoryIdentifier: darwinNotificationCategoryPlain,
    );

    const DarwinNotificationDetails macOSNotificationDetails =
        DarwinNotificationDetails(
      categoryIdentifier: darwinNotificationCategoryPlain,
    );

    const LinuxNotificationDetails linuxNotificationDetails =
        LinuxNotificationDetails(
      actions: <LinuxNotificationAction>[
        LinuxNotificationAction(
          key: urlLaunchActionId,
          label: 'Action 1',
        ),
        LinuxNotificationAction(
          key: navigationActionId,
          label: 'Action 2',
        ),
      ],
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
      macOS: macOSNotificationDetails,
      linux: linuxNotificationDetails,
    );
    await flutterLocalNotificationsPlugin.show(
        id++, 'plain title', 'plain body', notificationDetails,
        payload: 'item z');
  }

  Future<void> _showNotificationWithTextAction() async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'your channel id',
      'your channel name',
      channelDescription: 'your channel description',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'text_id_1',
          'Enter Text',
          icon: DrawableResourceAndroidBitmap('food'),
          inputs: <AndroidNotificationActionInput>[
            AndroidNotificationActionInput(
              label: 'Enter a message',
            ),
          ],
        ),
      ],
    );

    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
      categoryIdentifier: darwinNotificationCategoryText,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: darwinNotificationDetails,
      macOS: darwinNotificationDetails,
    );

    await flutterLocalNotificationsPlugin.show(id++, 'Text Input Notification',
        'Expand to see input action', notificationDetails,
        payload: 'item x');
  }

  Future<void> _showNotificationWithIconAction() async {
    const LinuxNotificationDetails linuxNotificationDetails =
        LinuxNotificationDetails(
      actions: <LinuxNotificationAction>[
        LinuxNotificationAction(
          key: 'media-eject',
          label: 'Eject',
        ),
      ],
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      linux: linuxNotificationDetails,
    );
    await flutterLocalNotificationsPlugin.show(
        id++, 'plain title', 'plain body', notificationDetails,
        payload: 'item z');
  }

  Future<void> _showNotificationWithTextChoice() async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'your channel id',
      'your channel name',
      channelDescription: 'your channel description',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'text_id_2',
          'Action 2',
          icon: DrawableResourceAndroidBitmap('food'),
          inputs: <AndroidNotificationActionInput>[
            AndroidNotificationActionInput(
              choices: <String>['ABC', 'DEF'],
              allowFreeFormInput: false,
            ),
          ],
          contextual: true,
        ),
      ],
    );

    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
      categoryIdentifier: darwinNotificationCategoryText,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: darwinNotificationDetails,
      macOS: darwinNotificationDetails,
    );
    await flutterLocalNotificationsPlugin.show(
        id++, 'plain title', 'plain body', notificationDetails,
        payload: 'item x');
  }

  Future<void> _requestFullScreenIntentPermission() async {
    final bool permissionGranted = await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestFullScreenIntentPermission() ??
        false;
    await showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
              content: Text(
                  'Full screen intent permission granted: $permissionGranted'),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            ));
  }

  Future<void> _showFullScreenNotification() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Turn off your screen'),
        content: const Text(
            'to see the full-screen intent in 5 seconds, press OK and TURN '
            'OFF your screen. Note that the full-screen intent permission must '
            'be granted for this to work too'),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await flutterLocalNotificationsPlugin.zonedSchedule(
                  0,
                  'scheduled title',
                  'scheduled body',
                  tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
                  const NotificationDetails(
                      android: AndroidNotificationDetails(
                          'full screen channel id', 'full screen channel name',
                          channelDescription: 'full screen channel description',
                          priority: Priority.high,
                          importance: Importance.high,
                          fullScreenIntent: true)),
                  androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
                  uiLocalNotificationDateInterpretation:
                      UILocalNotificationDateInterpretation.absoluteTime);

              Navigator.pop(context);
            },
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  Future<void> _showNotificationWithNoBody() async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('your channel id', 'your channel name',
            channelDescription: 'your channel description',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker');
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );
    await flutterLocalNotificationsPlugin.show(
        id++, 'plain title', null, notificationDetails,
        payload: 'item x');
  }

  Future<void> _showNotificationWithNoTitle() async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('your channel id', 'your channel name',
            channelDescription: 'your channel description',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker');
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );
    await flutterLocalNotificationsPlugin
        .show(id++, null, 'plain body', notificationDetails, payload: 'item x');
  }

  Future<void> _cancelNotification() async {
    await flutterLocalNotificationsPlugin.cancel(--id);
  }

  Future<void> _cancelNotificationWithTag() async {
    await flutterLocalNotificationsPlugin.cancel(--id, tag: 'tag');
  }

  Future<void> _showNotificationCustomSound() async {
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
    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: darwinNotificationDetails,
      macOS: darwinNotificationDetails,
    );
    await flutterLocalNotificationsPlugin.show(
      id++,
      'custom sound notification title',
      'custom sound notification body',
      notificationDetails,
    );
  }

  Future<void> _showNotificationCustomVibrationIconLed() async {
    final Int64List vibrationPattern = Int64List(4);
    vibrationPattern[0] = 0;
    vibrationPattern[1] = 1000;
    vibrationPattern[2] = 5000;
    vibrationPattern[3] = 2000;

    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
            'other custom channel id', 'other custom channel name',
            channelDescription: 'other custom channel description',
            icon: 'secondary_icon',
            largeIcon: const DrawableResourceAndroidBitmap('sample_large_icon'),
            vibrationPattern: vibrationPattern,
            enableLights: true,
            color: const Color.fromARGB(255, 255, 0, 0),
            ledColor: const Color.fromARGB(255, 255, 0, 0),
            ledOnMs: 1000,
            ledOffMs: 500);

    final NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
        id++,
        'title of notification with custom vibration pattern, LED and icon',
        'body of notification with custom vibration pattern, LED and icon',
        notificationDetails);
  }

  Future<void> _zonedScheduleNotification() async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
        0,
        'scheduled title',
        'scheduled body',
        tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
        const NotificationDetails(
            android: AndroidNotificationDetails(
                'your channel id', 'your channel name',
                channelDescription: 'your channel description')),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime);
  }

  Future<void> _zonedScheduleAlarmClockNotification() async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
        123,
        'scheduled alarm clock title',
        'scheduled alarm clock body',
        tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
        const NotificationDetails(
            android: AndroidNotificationDetails(
                'alarm_clock_channel', 'Alarm Clock Channel',
                channelDescription: 'Alarm Clock Notification')),
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime);
  }

  Future<void> _showNotificationWithNoSound() async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('silent channel id', 'silent channel name',
            channelDescription: 'silent channel description',
            playSound: false,
            styleInformation: DefaultStyleInformation(true, true));
    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
      presentSound: false,
    );
    const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: darwinNotificationDetails,
        macOS: darwinNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
        id++, '<b>silent</b> title', '<b>silent</b> body', notificationDetails);
  }

  Future<void> _showNotificationSilently() async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('your channel id', 'your channel name',
            channelDescription: 'your channel description',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker',
            silent: true);
    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
      presentSound: false,
    );
    const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: darwinNotificationDetails,
        macOS: darwinNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
        id++, '<b>silent</b> title', '<b>silent</b> body', notificationDetails);
  }

  Future<void> _showSoundUriNotification() async {
    /// this calls a method over a platform channel implemented within the
    /// example app to return the Uri for the default alarm sound and uses
    /// as the notification sound
    final String? alarmUri = await platform.invokeMethod<String>('getAlarmUri');
    final UriAndroidNotificationSound uriSound =
        UriAndroidNotificationSound(alarmUri!);
    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('uri channel id', 'uri channel name',
            channelDescription: 'uri channel description',
            sound: uriSound,
            styleInformation: const DefaultStyleInformation(true, true));
    final NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
        id++, 'uri sound title', 'uri sound body', notificationDetails);
  }

  Future<void> _showTimeoutNotification() async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('silent channel id', 'silent channel name',
            channelDescription: 'silent channel description',
            timeoutAfter: 3000,
            styleInformation: DefaultStyleInformation(true, true));
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.show(id++, 'timeout notification',
        'Times out after 3 seconds', notificationDetails);
  }

  Future<void> _showInsistentNotification() async {
    // This value is from: https://developer.android.com/reference/android/app/Notification.html#FLAG_INSISTENT
    const int insistentFlag = 4;
    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('your channel id', 'your channel name',
            channelDescription: 'your channel description',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker',
            additionalFlags: Int32List.fromList(<int>[insistentFlag]));
    final NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
        id++, 'insistent title', 'insistent body', notificationDetails,
        payload: 'item x');
  }

  Future<void> _showBigTextNotification() async {
    const BigTextStyleInformation bigTextStyleInformation =
        BigTextStyleInformation(
      'Lorem <i>ipsum dolor sit</i> amet, consectetur <b>adipiscing elit</b>, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.',
      htmlFormatBigText: true,
      contentTitle: 'overridden <b>big</b> content title',
      htmlFormatContentTitle: true,
      summaryText: 'summary <i>text</i>',
      htmlFormatSummaryText: true,
    );
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
            'big text channel id', 'big text channel name',
            channelDescription: 'big text channel description',
            styleInformation: bigTextStyleInformation);
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
        id++, 'big text title', 'silent body', notificationDetails);
  }

  Future<void> _showInboxNotification() async {
    final List<String> lines = <String>['line <b>1</b>', 'line <i>2</i>'];
    final InboxStyleInformation inboxStyleInformation = InboxStyleInformation(
        lines,
        htmlFormatLines: true,
        contentTitle: 'overridden <b>inbox</b> context title',
        htmlFormatContentTitle: true,
        summaryText: 'summary <i>text</i>',
        htmlFormatSummaryText: true);
    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('inbox channel id', 'inboxchannel name',
            channelDescription: 'inbox channel description',
            styleInformation: inboxStyleInformation);
    final NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
        id++, 'inbox title', 'inbox body', notificationDetails);
  }

  Future<void> _showGroupedNotifications() async {
    const String groupKey = 'com.android.example.WORK_EMAIL';
    const String groupChannelId = 'grouped channel id';
    const String groupChannelName = 'grouped channel name';
    const String groupChannelDescription = 'grouped channel description';
    // example based on https://developer.android.com/training/notify-user/group.html
    const AndroidNotificationDetails firstNotificationAndroidSpecifics =
        AndroidNotificationDetails(groupChannelId, groupChannelName,
            channelDescription: groupChannelDescription,
            importance: Importance.max,
            priority: Priority.high,
            groupKey: groupKey);
    const NotificationDetails firstNotificationPlatformSpecifics =
        NotificationDetails(android: firstNotificationAndroidSpecifics);
    await flutterLocalNotificationsPlugin.show(id++, 'Alex Faarborg',
        'You will not believe...', firstNotificationPlatformSpecifics);
    const AndroidNotificationDetails secondNotificationAndroidSpecifics =
        AndroidNotificationDetails(groupChannelId, groupChannelName,
            channelDescription: groupChannelDescription,
            importance: Importance.max,
            priority: Priority.high,
            groupKey: groupKey);
    const NotificationDetails secondNotificationPlatformSpecifics =
        NotificationDetails(android: secondNotificationAndroidSpecifics);
    await flutterLocalNotificationsPlugin.show(
        id++,
        'Jeff Chang',
        'Please join us to celebrate the...',
        secondNotificationPlatformSpecifics);

    // Create the summary notification to support older devices that pre-date
    /// Android 7.0 (API level 24).
    ///
    /// Recommended to create this regardless as the behaviour may vary as
    /// mentioned in https://developer.android.com/training/notify-user/group
    const List<String> lines = <String>[
      'Alex Faarborg  Check this out',
      'Jeff Chang    Launch Party'
    ];
    const InboxStyleInformation inboxStyleInformation = InboxStyleInformation(
        lines,
        contentTitle: '2 messages',
        summaryText: 'janedoe@example.com');
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(groupChannelId, groupChannelName,
            channelDescription: groupChannelDescription,
            styleInformation: inboxStyleInformation,
            groupKey: groupKey,
            setAsGroupSummary: true);
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
        id++, 'Attention', 'Two messages', notificationDetails);
  }

  Future<void> _showNotificationWithTag() async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('your channel id', 'your channel name',
            channelDescription: 'your channel description',
            importance: Importance.max,
            priority: Priority.high,
            tag: 'tag');
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );
    await flutterLocalNotificationsPlugin.show(
        id++, 'first notification', null, notificationDetails);
  }

  Future<void> _checkPendingNotificationRequests() async {
    final List<PendingNotificationRequest> pendingNotificationRequests =
        await flutterLocalNotificationsPlugin.pendingNotificationRequests();
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        content:
            Text('${pendingNotificationRequests.length} pending notification '
                'requests'),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> _showOngoingNotification() async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('your channel id', 'your channel name',
            channelDescription: 'your channel description',
            importance: Importance.max,
            priority: Priority.high,
            ongoing: true,
            autoCancel: false);
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
        id++,
        'ongoing notification title',
        'ongoing notification body',
        notificationDetails);
  }

  Future<void> _repeatNotification() async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
            'repeating channel id', 'repeating channel name',
            channelDescription: 'repeating description');
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.periodicallyShow(
      id++,
      'repeating title',
      'repeating body',
      RepeatInterval.everyMinute,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> _repeatPeriodicallyWithDurationNotification() async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
            'repeating channel id', 'repeating channel name',
            channelDescription: 'repeating description');
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.periodicallyShowWithDuration(
      id++,
      'repeating period title',
      'repeating period body',
      const Duration(minutes: 5),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> _scheduleDailyTenAMNotification() async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
        0,
        'daily scheduled notification title',
        'daily scheduled notification body',
        _nextInstanceOfTenAM(),
        const NotificationDetails(
          android: AndroidNotificationDetails('daily notification channel id',
              'daily notification channel name',
              channelDescription: 'daily notification description'),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time);
  }

  /// To test we don't validate past dates when using `matchDateTimeComponents`
  Future<void> _scheduleDailyTenAMLastYearNotification() async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
        0,
        'daily scheduled notification title',
        'daily scheduled notification body',
        _nextInstanceOfTenAMLastYear(),
        const NotificationDetails(
          android: AndroidNotificationDetails('daily notification channel id',
              'daily notification channel name',
              channelDescription: 'daily notification description'),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time);
  }

  Future<void> _scheduleWeeklyTenAMNotification() async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
        0,
        'weekly scheduled notification title',
        'weekly scheduled notification body',
        _nextInstanceOfTenAM(),
        const NotificationDetails(
          android: AndroidNotificationDetails('weekly notification channel id',
              'weekly notification channel name',
              channelDescription: 'weekly notificationdescription'),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime);
  }

  Future<void> _scheduleWeeklyMondayTenAMNotification() async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
        0,
        'weekly scheduled notification title',
        'weekly scheduled notification body',
        _nextInstanceOfMondayTenAM(),
        const NotificationDetails(
          android: AndroidNotificationDetails('weekly notification channel id',
              'weekly notification channel name',
              channelDescription: 'weekly notificationdescription'),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime);
  }

  Future<void> _scheduleMonthlyMondayTenAMNotification() async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
        0,
        'monthly scheduled notification title',
        'monthly scheduled notification body',
        _nextInstanceOfMondayTenAM(),
        const NotificationDetails(
          android: AndroidNotificationDetails('monthly notification channel id',
              'monthly notification channel name',
              channelDescription: 'monthly notificationdescription'),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime);
  }

  Future<void> _scheduleYearlyMondayTenAMNotification() async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
        0,
        'yearly scheduled notification title',
        'yearly scheduled notification body',
        _nextInstanceOfMondayTenAM(),
        const NotificationDetails(
          android: AndroidNotificationDetails('yearly notification channel id',
              'yearly notification channel name',
              channelDescription: 'yearly notification description'),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dateAndTime);
  }

  tz.TZDateTime _nextInstanceOfTenAM() {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 10);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfTenAMLastYear() {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    return tz.TZDateTime(tz.local, now.year - 1, now.month, now.day, 10);
  }

  tz.TZDateTime _nextInstanceOfMondayTenAM() {
    tz.TZDateTime scheduledDate = _nextInstanceOfTenAM();
    while (scheduledDate.weekday != DateTime.monday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> _showNotificationWithNoBadge() async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('no badge channel', 'no badge name',
            channelDescription: 'no badge description',
            channelShowBadge: false,
            importance: Importance.max,
            priority: Priority.high,
            onlyAlertOnce: true);
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
        id++, 'no badge title', 'no badge body', notificationDetails,
        payload: 'item x');
  }

  Future<void> _showProgressNotification() async {
    id++;
    final int progressId = id;
    const int maxProgress = 5;
    for (int i = 0; i <= maxProgress; i++) {
      await Future<void>.delayed(const Duration(seconds: 1), () async {
        final AndroidNotificationDetails androidNotificationDetails =
            AndroidNotificationDetails('progress channel', 'progress channel',
                channelDescription: 'progress channel description',
                channelShowBadge: false,
                importance: Importance.max,
                priority: Priority.high,
                onlyAlertOnce: true,
                showProgress: true,
                maxProgress: maxProgress,
                progress: i);
        final NotificationDetails notificationDetails =
            NotificationDetails(android: androidNotificationDetails);
        await flutterLocalNotificationsPlugin.show(
            progressId,
            'progress notification title',
            'progress notification body',
            notificationDetails,
            payload: 'item x');
      });
    }
  }

  Future<void> _showIndeterminateProgressNotification() async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
            'indeterminate progress channel', 'indeterminate progress channel',
            channelDescription: 'indeterminate progress channel description',
            channelShowBadge: false,
            importance: Importance.max,
            priority: Priority.high,
            onlyAlertOnce: true,
            showProgress: true,
            indeterminate: true);
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
        id++,
        'indeterminate progress notification title',
        'indeterminate progress notification body',
        notificationDetails,
        payload: 'item x');
  }

  Future<void> _showNotificationUpdateChannelDescription() async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('your channel id', 'your channel name',
            channelDescription: 'your updated channel description',
            importance: Importance.max,
            priority: Priority.high,
            channelAction: AndroidNotificationChannelAction.update);
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
        id++,
        'updated notification channel',
        'check settings to see updated channel description',
        notificationDetails,
        payload: 'item x');
  }

  Future<void> _showPublicNotification() async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('your channel id', 'your channel name',
            channelDescription: 'your channel description',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker',
            visibility: NotificationVisibility.public);
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
        id++,
        'public notification title',
        'public notification body',
        notificationDetails,
        payload: 'item x');
  }

  Future<void> _showNotificationWithSubtitle() async {
    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
      subtitle: 'the subtitle',
    );
    const NotificationDetails notificationDetails = NotificationDetails(
        iOS: darwinNotificationDetails, macOS: darwinNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
        id++,
        'title of notification with a subtitle',
        'body of notification with a subtitle',
        notificationDetails,
        payload: 'item x');
  }

  Future<void> _showNotificationWithIconBadge() async {
    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(badgeNumber: 1);
    const NotificationDetails notificationDetails = NotificationDetails(
        iOS: darwinNotificationDetails, macOS: darwinNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
        id++, 'icon badge title', 'icon badge body', notificationDetails,
        payload: 'item x');
  }

  Future<void> _showNotificationsWithThreadIdentifier() async {
    NotificationDetails buildNotificationDetailsForThread(
      String threadIdentifier,
    ) {
      final DarwinNotificationDetails darwinNotificationDetails =
          DarwinNotificationDetails(
        threadIdentifier: threadIdentifier,
      );
      return NotificationDetails(
          iOS: darwinNotificationDetails, macOS: darwinNotificationDetails);
    }

    final NotificationDetails thread1PlatformChannelSpecifics =
        buildNotificationDetailsForThread('thread1');
    final NotificationDetails thread2PlatformChannelSpecifics =
        buildNotificationDetailsForThread('thread2');

    await flutterLocalNotificationsPlugin.show(id++, 'thread 1',
        'first notification', thread1PlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(id++, 'thread 1',
        'second notification', thread1PlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(id++, 'thread 1',
        'third notification', thread1PlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(id++, 'thread 2',
        'first notification', thread2PlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(id++, 'thread 2',
        'second notification', thread2PlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(id++, 'thread 2',
        'third notification', thread2PlatformChannelSpecifics);
  }

  Future<void> _showNotificationWithTimeSensitiveInterruptionLevel() async {
    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    const NotificationDetails notificationDetails = NotificationDetails(
        iOS: darwinNotificationDetails, macOS: darwinNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
        id++,
        'title of time sensitive notification',
        'body of time sensitive notification',
        notificationDetails,
        payload: 'item x');
  }

  Future<void> _showNotificationWithBannerNotInNotificationCentre() async {
    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
      presentBanner: true,
      presentList: false,
    );
    const NotificationDetails notificationDetails = NotificationDetails(
        iOS: darwinNotificationDetails, macOS: darwinNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
        id++,
        'title of banner notification',
        'body of banner notification',
        notificationDetails,
        payload: 'item x');
  }

  Future<void> _showNotificationInNotificationCentreOnly() async {
    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
      presentBanner: false,
      presentList: true,
    );
    const NotificationDetails notificationDetails = NotificationDetails(
        iOS: darwinNotificationDetails, macOS: darwinNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
        id++,
        'title of notification shown only in notification centre',
        'body of notification shown only in notification centre',
        notificationDetails,
        payload: 'item x');
  }

  Future<void> _showNotificationWithoutTimestamp() async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('your channel id', 'your channel name',
            channelDescription: 'your channel description',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: false);
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
        id++, 'plain title', 'plain body', notificationDetails,
        payload: 'item x');
  }

  Future<void> _showNotificationWithCustomTimestamp() async {
    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'your channel id',
      'your channel name',
      channelDescription: 'your channel description',
      importance: Importance.max,
      priority: Priority.high,
      when: DateTime.now().millisecondsSinceEpoch - 120 * 1000,
    );
    final NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
        id++, 'plain title', 'plain body', notificationDetails,
        payload: 'item x');
  }

  Future<void> _showNotificationWithCustomSubText() async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'your channel id',
      'your channel name',
      channelDescription: 'your channel description',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
      subText: 'custom subtext',
    );
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
        id++, 'plain title', 'plain body', notificationDetails,
        payload: 'item x');
  }

  Future<void> _showNotificationWithChronometer() async {
    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'your channel id',
      'your channel name',
      channelDescription: 'your channel description',
      importance: Importance.max,
      priority: Priority.high,
      when: DateTime.now().millisecondsSinceEpoch - 120 * 1000,
      usesChronometer: true,
      chronometerCountDown: true,
    );
    final NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
        id++, 'plain title', 'plain body', notificationDetails,
        payload: 'item x');
  }

  Future<void> _createNotificationChannelGroup() async {
    const String channelGroupId = 'your channel group id';
    // create the group first
    const AndroidNotificationChannelGroup androidNotificationChannelGroup =
        AndroidNotificationChannelGroup(
            channelGroupId, 'your channel group name',
            description: 'your channel group description');
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()!
        .createNotificationChannelGroup(androidNotificationChannelGroup);

    // create channels associated with the group
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()!
        .createNotificationChannel(const AndroidNotificationChannel(
            'grouped channel id 1', 'grouped channel name 1',
            description: 'grouped channel description 1',
            groupId: channelGroupId));

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()!
        .createNotificationChannel(const AndroidNotificationChannel(
            'grouped channel id 2', 'grouped channel name 2',
            description: 'grouped channel description 2',
            groupId: channelGroupId));

    await showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
              content: Text('Channel group with name '
                  '${androidNotificationChannelGroup.name} created'),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            ));
  }

  Future<void> _deleteNotificationChannelGroup() async {
    const String channelGroupId = 'your channel group id';
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.deleteNotificationChannelGroup(channelGroupId);

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        content: const Text('Channel group with id $channelGroupId deleted'),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _startForegroundService() async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('your channel id', 'your channel name',
            channelDescription: 'your channel description',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker');
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.startForegroundService(1, 'plain title', 'plain body',
            notificationDetails: androidNotificationDetails, payload: 'item x');
  }

  Future<void> _startForegroundServiceWithBlueBackgroundNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'your channel id',
      'your channel name',
      channelDescription: 'color background channel description',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      color: Colors.blue,
      colorized: true,
    );

    /// only using foreground service can color the background
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.startForegroundService(
            1, 'colored background text title', 'colored background text body',
            notificationDetails: androidPlatformChannelSpecifics,
            payload: 'item x');
  }

  Future<void> _stopForegroundService() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.stopForegroundService();
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel androidNotificationChannel =
        AndroidNotificationChannel(
      'your channel id 2',
      'your channel name 2',
      description: 'your channel description 2',
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidNotificationChannel);

    await showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
              content:
                  Text('Channel with name ${androidNotificationChannel.name} '
                      'created'),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            ));
  }

  Future<void> _areNotifcationsEnabledOnAndroid() async {
    final bool? areEnabled = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.areNotificationsEnabled();
    await showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
              content: Text(areEnabled == null
                  ? 'ERROR: received null'
                  : (areEnabled
                      ? 'Notifications are enabled'
                      : 'Notifications are NOT enabled')),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            ));
  }

  Future<void> _checkNotificationsOnCupertino() async {
    final NotificationsEnabledOptions? isEnabled =
        await flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                    IOSFlutterLocalNotificationsPlugin>()
                ?.checkPermissions() ??
            await flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                    MacOSFlutterLocalNotificationsPlugin>()
                ?.checkPermissions();
    final String isEnabledString = isEnabled == null
        ? 'ERROR: received null'
        : '''
    isEnabled: ${isEnabled.isEnabled}
    isSoundEnabled: ${isEnabled.isSoundEnabled}
    isAlertEnabled: ${isEnabled.isAlertEnabled}
    isBadgeEnabled: ${isEnabled.isBadgeEnabled}
    isProvisionalEnabled: ${isEnabled.isProvisionalEnabled}
    isCriticalEnabled: ${isEnabled.isCriticalEnabled}
    ''';
    await showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
              content: Text(isEnabledString),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            ));
  }

  Future<void> _deleteNotificationChannel() async {
    const String channelId = 'your channel id 2';
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.deleteNotificationChannel(channelId);

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        content: const Text('Channel with id $channelId deleted'),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _getNotificationChannels() async {
    final Widget notificationChannelsDialogContent =
        await _getNotificationChannelsDialogContent();
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        content: notificationChannelsDialogContent,
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<Widget> _getNotificationChannelsDialogContent() async {
    try {
      final List<AndroidNotificationChannel>? channels =
          await flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()!
              .getNotificationChannels();

      return Container(
        width: double.maxFinite,
        child: ListView(
          children: <Widget>[
            const Text(
              'Notifications Channels',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Divider(color: Colors.black),
            if (channels?.isEmpty ?? true)
              const Text('No notification channels')
            else
              for (final AndroidNotificationChannel channel in channels!)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('id: ${channel.id}\n'
                        'name: ${channel.name}\n'
                        'description: ${channel.description}\n'
                        'groupId: ${channel.groupId}\n'
                        'importance: ${channel.importance.value}\n'
                        'playSound: ${channel.playSound}\n'
                        'sound: ${channel.sound?.sound}\n'
                        'enableVibration: ${channel.enableVibration}\n'
                        'vibrationPattern: ${channel.vibrationPattern}\n'
                        'showBadge: ${channel.showBadge}\n'
                        'enableLights: ${channel.enableLights}\n'
                        'ledColor: ${channel.ledColor}\n'
                        'audioAttributesUsage: ${channel.audioAttributesUsage}\n'),
                    const Divider(color: Colors.black),
                  ],
                ),
          ],
        ),
      );
    } on PlatformException catch (error) {
      return Text(
        'Error calling "getNotificationChannels"\n'
        'code: ${error.code}\n'
        'message: ${error.message}',
      );
    }
  }

  Future<void> _showNotificationWithNumber() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails('your channel id', 'your channel name',
            channelDescription: 'your channel description',
            importance: Importance.max,
            priority: Priority.high,
            number: 1);
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
        0, 'icon badge title', 'icon badge body', platformChannelSpecifics,
        payload: 'item x');
  }

  Future<void> _showNotificationWithAudioAttributeAlarm() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'your alarm channel id',
      'your alarm channel name',
      channelDescription: 'your alarm channel description',
      importance: Importance.max,
      priority: Priority.high,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      0,
      'notification sound controlled by alarm volume',
      'alarm notification sound body',
      platformChannelSpecifics,
    );
  }
}

Future<void> _showLinuxNotificationWithBodyMarkup() async {
  await flutterLocalNotificationsPlugin.show(
    id++,
    'notification with body markup',
    '<b>bold text</b>\n'
        '<i>italic text</i>\n'
        '<u>underline text</u>\n'
        'https://example.com\n'
        '<a href="https://example.com">example.com</a>',
    null,
  );
}

Future<void> _showLinuxNotificationWithCategory() async {
  const LinuxNotificationDetails linuxPlatformChannelSpecifics =
      LinuxNotificationDetails(
    category: LinuxNotificationCategory.emailArrived,
  );
  const NotificationDetails notificationDetails = NotificationDetails(
    linux: linuxPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    id++,
    'notification with category',
    null,
    notificationDetails,
  );
}

Future<void> _showLinuxNotificationWithPathIcon(String path) async {
  final LinuxNotificationDetails linuxPlatformChannelSpecifics =
      LinuxNotificationDetails(icon: FilePathLinuxIcon(path));
  final NotificationDetails platformChannelSpecifics = NotificationDetails(
    linux: linuxPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    0,
    'notification with file path icon',
    null,
    platformChannelSpecifics,
  );
}

Future<void> _showLinuxNotificationWithThemeIcon() async {
  final LinuxNotificationDetails linuxPlatformChannelSpecifics =
      LinuxNotificationDetails(
    icon: ThemeLinuxIcon('media-eject'),
  );
  final NotificationDetails notificationDetails = NotificationDetails(
    linux: linuxPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    id++,
    'notification with theme icon',
    null,
    notificationDetails,
  );
}

Future<void> _showLinuxNotificationWithThemeSound() async {
  final LinuxNotificationDetails linuxPlatformChannelSpecifics =
      LinuxNotificationDetails(
    sound: ThemeLinuxSound('message-new-email'),
  );
  final NotificationDetails notificationDetails = NotificationDetails(
    linux: linuxPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    id++,
    'notification with theme sound',
    null,
    notificationDetails,
  );
}

Future<void> _showLinuxNotificationWithCriticalUrgency() async {
  const LinuxNotificationDetails linuxPlatformChannelSpecifics =
      LinuxNotificationDetails(
    urgency: LinuxNotificationUrgency.critical,
  );
  const NotificationDetails notificationDetails = NotificationDetails(
    linux: linuxPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    id++,
    'notification with critical urgency',
    null,
    notificationDetails,
  );
}

Future<void> _showLinuxNotificationWithTimeout() async {
  final LinuxNotificationDetails linuxPlatformChannelSpecifics =
      LinuxNotificationDetails(
    timeout: LinuxNotificationTimeout.fromDuration(
      const Duration(seconds: 1),
    ),
  );
  final NotificationDetails notificationDetails = NotificationDetails(
    linux: linuxPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    id++,
    'notification with timeout',
    null,
    notificationDetails,
  );
}

Future<void> _showLinuxNotificationSuppressSound() async {
  const LinuxNotificationDetails linuxPlatformChannelSpecifics =
      LinuxNotificationDetails(
    suppressSound: true,
  );
  const NotificationDetails notificationDetails = NotificationDetails(
    linux: linuxPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    id++,
    'suppress notification sound',
    null,
    notificationDetails,
  );
}

Future<void> _showLinuxNotificationTransient() async {
  const LinuxNotificationDetails linuxPlatformChannelSpecifics =
      LinuxNotificationDetails(
    transient: true,
  );
  const NotificationDetails notificationDetails = NotificationDetails(
    linux: linuxPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    id++,
    'transient notification',
    null,
    notificationDetails,
  );
}

Future<void> _showLinuxNotificationResident() async {
  const LinuxNotificationDetails linuxPlatformChannelSpecifics =
      LinuxNotificationDetails(
    resident: true,
  );
  const NotificationDetails notificationDetails = NotificationDetails(
    linux: linuxPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    id++,
    'resident notification',
    null,
    notificationDetails,
  );
}

Future<void> _showLinuxNotificationDifferentLocation() async {
  const LinuxNotificationDetails linuxPlatformChannelSpecifics =
      LinuxNotificationDetails(location: LinuxNotificationLocation(10, 10));
  const NotificationDetails notificationDetails = NotificationDetails(
    linux: linuxPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    id++,
    'notification on different screen location',
    null,
    notificationDetails,
  );
}

Future<LinuxServerCapabilities> getLinuxCapabilities() =>
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            LinuxFlutterLocalNotificationsPlugin>()!
        .getCapabilities();

class SecondPage extends StatefulWidget {
  const SecondPage(
    this.payload, {
    Key? key,
  }) : super(key: key);

  static const String routeName = '/secondPage';

  final String? payload;

  @override
  State<StatefulWidget> createState() => SecondPageState();
}

class SecondPageState extends State<SecondPage> {
  String? _payload;

  @override
  void initState() {
    super.initState();
    _payload = widget.payload;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Second Screen'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('payload ${_payload ?? ''}'),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Go back!'),
              ),
            ],
          ),
        ),
      );
}

class _InfoValueString extends StatelessWidget {
  const _InfoValueString({
    required this.title,
    required this.value,
    Key? key,
  }) : super(key: key);

  final String title;
  final Object? value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
        child: Text.rich(
          TextSpan(
            children: <InlineSpan>[
              TextSpan(
                text: '$title ',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: '$value',
              )
            ],
          ),
        ),
      );
}
