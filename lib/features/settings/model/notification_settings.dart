import 'package:career_client_agent/core/constants/app_constants.dart';

class NotificationSettings {
  const NotificationSettings({
    this.isEnabled = false,
    this.dailyReportHour = AppConstants.defaultDailyReportHour,
    this.dailyReportMinute = AppConstants.defaultDailyReportMinute,
    this.deadlineReminderDays = AppConstants.defaultDeadlineReminderDays,
    this.highMatchThreshold = AppConstants.defaultHighMatchThreshold,
  });

  final bool isEnabled;
  final int dailyReportHour;
  final int dailyReportMinute;
  final int deadlineReminderDays;
  final int highMatchThreshold;

  NotificationSettings copyWith({
    bool? isEnabled,
    int? dailyReportHour,
    int? dailyReportMinute,
    int? deadlineReminderDays,
    int? highMatchThreshold,
  }) {
    return NotificationSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      dailyReportHour: dailyReportHour ?? this.dailyReportHour,
      dailyReportMinute: dailyReportMinute ?? this.dailyReportMinute,
      deadlineReminderDays: deadlineReminderDays ?? this.deadlineReminderDays,
      highMatchThreshold: highMatchThreshold ?? this.highMatchThreshold,
    );
  }
}
