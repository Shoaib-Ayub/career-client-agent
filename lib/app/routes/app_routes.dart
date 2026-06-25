abstract final class AppRoutes {
  static const splashName = 'splash';
  static const splashPath = '/';

  static const dashboardName = 'dashboard';
  static const dashboardPath = '/dashboard';

  static const jobsName = 'jobs';
  static const jobsPath = '/jobs';

  static const scholarshipsName = 'scholarships';
  static const scholarshipsPath = '/scholarships';

  static const governmentJobsName = 'government-jobs';
  static const governmentJobsPath = '/government-jobs';

  static const clientLeadsName = 'client-leads';
  static const clientLeadsPath = '/client-leads';

  static const searchTasksName = 'search-tasks';
  static const searchTasksPath = '/search-tasks';
  static const addSearchTaskName = 'add-search-task';
  static const addSearchTaskPath = '/search-tasks/add';
  static const editSearchTaskName = 'edit-search-task';
  static const editSearchTaskPath = '/search-tasks/edit/:taskId';
  static const taskIdParameter = 'taskId';

  static const applicationTrackerName = 'application-tracker';
  static const applicationTrackerPath = '/application-tracker';

  static const profileName = 'profile';
  static const profilePath = '/profile';

  static const settingsName = 'settings';
  static const settingsPath = '/settings';
  static const notificationSettingsName = 'notification-settings';
  static const notificationSettingsPath = '/settings/notifications';
  static const dataRefreshSettingsName = 'data-refresh-settings';
  static const dataRefreshSettingsPath = '/settings/data-refresh';

  static const dailyReportName = 'daily-report';
  static const dailyReportPath = '/daily-report';

  static const profileOptimizerName = 'profile-optimizer';
  static const profileOptimizerPath = '/profile-optimizer';
}
