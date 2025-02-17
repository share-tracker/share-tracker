part of '../../share_tracker.dart';

typedef TrackerChanged = void Function(Tracker tracker);

class TrackerService {
  TrackerService._();

  void _onReceiveTaskData(Object obj) {
    if (obj is Map<String, dynamic>) {
      for (final callback in _callbacks) {
        callback(Tracker.fromJson(obj));
      }
    }
  }

  void addTrackerChangedCallback(TrackerChanged callback) {
    if (!_callbacks.contains(callback)) _callbacks.add(callback);
  }

  void removeTrackerChangedCallback(TrackerChanged callback) {
    _callbacks.remove(callback);
  }

  void init({String? id, String? name}) {
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: id ?? 'tracker_service',
        channelName: name ?? 'Tracker Service',
        channelImportance: NotificationChannelImportance.HIGH,
        onlyAlertOnce: true,
        priority: NotificationPriority.HIGH,
      ),
      iosNotificationOptions:
          const IOSNotificationOptions(showNotification: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        allowWifiLock: true,
        autoRunOnBoot: true,
        eventAction: ForegroundTaskEventAction.repeat(1000),
      ),
    );
  }

  Future<bool> start(int id, String title) async {
    bool responsePermission = true;

    responsePermission = await _requestPlatformPermissions();
    responsePermission = await _requestTrackerPermission();

    if (responsePermission) {
      final result = await FlutterForegroundTask.startService(
        serviceId: id,
        notificationTitle: title,
        notificationText: '',
        callback: startTracker,
      );

      if (result is ServiceRequestFailure) throw result.error;
    }
    return responsePermission;
  }

  Future<void> stop() async {
    final result = await FlutterForegroundTask.stopService();

    if (result is ServiceRequestFailure) throw result.error;
  }

  Future<bool> _requestPlatformPermissions() async {
    bool responsePermission = true;

    if (NotificationPermission.granted !=
        await FlutterForegroundTask.checkNotificationPermission()) {
      final _ = await FlutterForegroundTask.requestNotificationPermission();

      responsePermission = NotificationPermission.granted ==
          await FlutterForegroundTask.checkNotificationPermission();
    }

    if (Platform.isAndroid) {
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        responsePermission =
            await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }

      if (!await FlutterForegroundTask.canDrawOverlays) {
        responsePermission =
            await FlutterForegroundTask.openSystemAlertWindowSettings();
      }

      if (!await Permission.activityRecognition.isGranted) {
        responsePermission =
            (await Permission.activityRecognition.request()).isGranted;
      }
    } else {
      if (!await Permission.sensors.isGranted) {
        responsePermission = (await Permission.sensors.request()).isGranted;
      }
    }
    return responsePermission;
  }

  Future<bool> _requestTrackerPermission() async {
    if (LocationPermission.always != await Geolocator.checkPermission()) {
      return await _requestGeolocatorPermission();
    }
    return LocationPermission.always == await Geolocator.checkPermission();
  }

  Future<bool> _requestGeolocatorPermission() async {
    if (LocationPermission.always != await Geolocator.checkPermission()) {
      final requestGeoPermission = await Geolocator.requestPermission();

      if (LocationPermission.deniedForever == requestGeoPermission ||
          LocationPermission.denied == requestGeoPermission) {
        return await openAppSettings();
      }
      return Platform.isIOS
          ? LocationPermission.whileInUse == requestGeoPermission
          : LocationPermission.always == await Geolocator.requestPermission();
    }
    return Platform.isIOS
        ? LocationPermission.whileInUse == await Geolocator.checkPermission()
        : LocationPermission.always == await Geolocator.checkPermission();
  }

  Future<bool> get isRunningService => FlutterForegroundTask.isRunningService;

  final _callbacks = <TrackerChanged>[];

  static final instance = TrackerService._();
}
