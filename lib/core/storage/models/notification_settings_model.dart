import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/storage/local_model.dart';
import 'package:career_client_agent/features/settings/model/notification_settings.dart';

class NotificationSettingsModel implements LocalModel {
  const NotificationSettingsModel({
    required this.isEnabled,
    required this.dailyReportHour,
    required this.dailyReportMinute,
    required this.deadlineReminderDays,
    required this.highMatchThreshold,
  });

  @override
  String get id => AppConstants.notificationSettingsRecordId;

  final bool isEnabled;
  final int dailyReportHour;
  final int dailyReportMinute;
  final int deadlineReminderDays;
  final int highMatchThreshold;

  factory NotificationSettingsModel.fromDomain(NotificationSettings settings) {
    return NotificationSettingsModel(
      isEnabled: settings.isEnabled,
      dailyReportHour: settings.dailyReportHour,
      dailyReportMinute: settings.dailyReportMinute,
      deadlineReminderDays: settings.deadlineReminderDays,
      highMatchThreshold: settings.highMatchThreshold,
    );
  }

  factory NotificationSettingsModel.fromMap(Map<dynamic, dynamic> map) {
    return NotificationSettingsModel(
      isEnabled: (map['isEnabled'] ?? false) as bool,
      dailyReportHour:
          (map['dailyReportHour'] ?? AppConstants.defaultDailyReportHour)
              as int,
      dailyReportMinute:
          (map['dailyReportMinute'] ?? AppConstants.defaultDailyReportMinute)
              as int,
      deadlineReminderDays:
          (map['deadlineReminderDays'] ??
                  AppConstants.defaultDeadlineReminderDays)
              as int,
      highMatchThreshold:
          (map['highMatchThreshold'] ?? AppConstants.defaultHighMatchThreshold)
              as int,
    );
  }

  NotificationSettings toDomain() => NotificationSettings(
    isEnabled: isEnabled,
    dailyReportHour: dailyReportHour,
    dailyReportMinute: dailyReportMinute,
    deadlineReminderDays: deadlineReminderDays,
    highMatchThreshold: highMatchThreshold,
  );

  @override
  Map<String, Object> toMap() => {
    'isEnabled': isEnabled,
    'dailyReportHour': dailyReportHour,
    'dailyReportMinute': dailyReportMinute,
    'deadlineReminderDays': deadlineReminderDays,
    'highMatchThreshold': highMatchThreshold,
  };
}
