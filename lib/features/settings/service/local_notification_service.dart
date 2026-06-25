import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/storage/models/opportunity_result.dart';
import 'package:career_client_agent/features/application_tracker/model/application_tracker_item.dart';
import 'package:career_client_agent/features/settings/model/notification_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

abstract interface class NotificationService {
  Future<void> initialize();

  Future<bool> requestPermission();

  Future<void> applySettings({
    required NotificationSettings settings,
    required List<ApplicationTrackerItem> applications,
  });

  Future<void> showDailyReportAvailable();

  Future<void> showHighMatchJobs(
    List<OpportunityResult> jobs,
    NotificationSettings settings,
  );
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return LocalNotificationService();
});

class LocalNotificationService implements NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  bool _initializationFailed = false;

  bool get _supportsNotifications =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  Future<void> initialize() async {
    if (_isInitialized || _initializationFailed || !_supportsNotifications) {
      return;
    }

    timezone_data.initializeTimeZones();
    const android = AndroidInitializationSettings(
      AppConstants.notificationAndroidIcon,
    );
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: android,
          iOS: darwin,
          macOS: darwin,
        ),
      );
      _isInitialized = true;
    } on Object {
      _initializationFailed = true;
    }
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();
    if (!_supportsNotifications || !_isInitialized) {
      return false;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }

  @override
  Future<void> applySettings({
    required NotificationSettings settings,
    required List<ApplicationTrackerItem> applications,
  }) async {
    if (!settings.isEnabled && !_isInitialized) {
      return;
    }
    await initialize();
    if (!_supportsNotifications || !_isInitialized) {
      return;
    }

    await _plugin.cancelAllPendingNotifications();
    if (!settings.isEnabled) {
      return;
    }

    await _scheduleDailyReport(settings);
    for (final application in applications) {
      await _scheduleDeadline(application, settings);
      await _scheduleFollowUp(application, settings);
    }
  }

  @override
  Future<void> showDailyReportAvailable() async {
    await initialize();
    if (!_supportsNotifications || !_isInitialized) {
      return;
    }
    await _plugin.show(
      id: AppConstants.notificationDailyReportAvailableId,
      title: AppStrings.dailyReportNotificationTitle,
      body: AppStrings.dailyReportNotificationBody,
      notificationDetails: _details,
      payload: AppStrings.notificationPayloadDailyReport,
    );
  }

  @override
  Future<void> showHighMatchJobs(
    List<OpportunityResult> jobs,
    NotificationSettings settings,
  ) async {
    if (!settings.isEnabled) {
      return;
    }
    await initialize();
    if (!_supportsNotifications || !_isInitialized) {
      return;
    }

    for (final job in jobs.where(
      (item) => item.matchScore >= settings.highMatchThreshold,
    )) {
      await _plugin.show(
        id: AppConstants.notificationHighMatchIdOffset + _stableId(job.id),
        title: AppStrings.highMatchNotificationTitle,
        body: AppStrings.highMatchNotificationBody(job.title, job.matchScore),
        notificationDetails: _details,
        payload: AppStrings.notificationPayloadHighMatch,
      );
    }
  }

  Future<void> _scheduleDailyReport(NotificationSettings settings) async {
    final scheduledDate = _nextOccurrence(
      hour: settings.dailyReportHour,
      minute: settings.dailyReportMinute,
    );
    await _plugin.zonedSchedule(
      id: AppConstants.notificationDailyReportId,
      title: AppStrings.dailyReportNotificationTitle,
      body: AppStrings.dailyReportNotificationBody,
      scheduledDate: scheduledDate,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: AppStrings.notificationPayloadDailyReport,
    );
  }

  Future<void> _scheduleDeadline(
    ApplicationTrackerItem application,
    NotificationSettings settings,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadlineDay = DateTime(
      application.deadline.year,
      application.deadline.month,
      application.deadline.day,
    );
    final deadline = DateTime(
      application.deadline.year,
      application.deadline.month,
      application.deadline.day,
      settings.dailyReportHour,
      settings.dailyReportMinute,
    );
    if (deadlineDay.isBefore(today)) {
      return;
    }
    final reminderDate = deadline.subtract(
      Duration(days: settings.deadlineReminderDays),
    );
    final localDate = reminderDate.isAfter(now)
        ? reminderDate
        : now.add(AppConstants.notificationImmediateDelay);
    final remainingDays = deadlineDay.difference(today).inDays;

    await _plugin.zonedSchedule(
      id: AppConstants.notificationDeadlineIdOffset + _stableId(application.id),
      title: AppStrings.deadlineNotificationTitle,
      body: AppStrings.deadlineNotificationBody(
        application.title,
        remainingDays,
      ),
      scheduledDate: _asUtcLocation(localDate),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: AppStrings.notificationPayloadDeadline,
    );
  }

  Future<void> _scheduleFollowUp(
    ApplicationTrackerItem application,
    NotificationSettings settings,
  ) async {
    final followUpDate = application.followUpDate;
    if (followUpDate == null) {
      return;
    }
    final localDate = DateTime(
      followUpDate.year,
      followUpDate.month,
      followUpDate.day,
      settings.dailyReportHour,
      settings.dailyReportMinute,
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final followUpDay = DateTime(
      followUpDate.year,
      followUpDate.month,
      followUpDate.day,
    );
    if (followUpDay.isBefore(today)) {
      return;
    }
    final scheduledDate = localDate.isAfter(now)
        ? localDate
        : now.add(AppConstants.notificationImmediateDelay);

    await _plugin.zonedSchedule(
      id: AppConstants.notificationFollowUpIdOffset + _stableId(application.id),
      title: AppStrings.followUpNotificationTitle,
      body: AppStrings.followUpNotificationBody(application.title),
      scheduledDate: _asUtcLocation(scheduledDate),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: AppStrings.notificationPayloadFollowUp,
    );
  }

  timezone.TZDateTime _nextOccurrence({
    required int hour,
    required int minute,
  }) {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    return _asUtcLocation(next);
  }

  timezone.TZDateTime _asUtcLocation(DateTime localDate) {
    return timezone.TZDateTime.from(localDate.toUtc(), timezone.UTC);
  }

  int _stableId(String value) {
    var hash = 0;
    for (final codeUnit in value.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return hash % AppConstants.notificationIdRange;
  }

  NotificationDetails get _details => const NotificationDetails(
    android: AndroidNotificationDetails(
      AppConstants.notificationChannelId,
      AppStrings.notificationChannelName,
      channelDescription: AppStrings.notificationChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
    macOS: DarwinNotificationDetails(),
  );
}
