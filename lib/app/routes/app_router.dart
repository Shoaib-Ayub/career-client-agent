import 'package:career_client_agent/app/main_navigation_screen.dart';
import 'package:career_client_agent/app/routes/app_routes.dart';
import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/features/search_tasks/view/task_form_screen.dart';
import 'package:career_client_agent/features/splash/view/splash_screen.dart';
import 'package:career_client_agent/features/settings/view/data_refresh_settings_screen.dart';
import 'package:career_client_agent/features/settings/view/settings_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splashPath,
    routes: [
      GoRoute(
        name: AppRoutes.splashName,
        path: AppRoutes.splashPath,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        name: AppRoutes.dashboardName,
        path: AppRoutes.dashboardPath,
        builder: (context, state) => const MainNavigationScreen(
          initialIndex: AppConstants.dashboardTabIndex,
        ),
      ),
      GoRoute(
        name: AppRoutes.jobsName,
        path: AppRoutes.jobsPath,
        builder: (context, state) =>
            const MainNavigationScreen(initialIndex: AppConstants.jobsTabIndex),
      ),
      GoRoute(
        name: AppRoutes.scholarshipsName,
        path: AppRoutes.scholarshipsPath,
        builder: (context, state) => const MainNavigationScreen(
          initialIndex: AppConstants.scholarshipsTabIndex,
        ),
      ),
      GoRoute(
        name: AppRoutes.governmentJobsName,
        path: AppRoutes.governmentJobsPath,
        builder: (context, state) => const MainNavigationScreen(
          initialIndex: AppConstants.governmentJobsTabIndex,
        ),
      ),
      GoRoute(
        name: AppRoutes.clientLeadsName,
        path: AppRoutes.clientLeadsPath,
        builder: (context, state) => const MainNavigationScreen(
          initialIndex: AppConstants.clientsTabIndex,
        ),
      ),
      GoRoute(
        name: AppRoutes.searchTasksName,
        path: AppRoutes.searchTasksPath,
        builder: (context, state) => const MainNavigationScreen(
          initialIndex: AppConstants.tasksTabIndex,
        ),
      ),
      GoRoute(
        name: AppRoutes.addSearchTaskName,
        path: AppRoutes.addSearchTaskPath,
        builder: (context, state) => const TaskFormScreen(),
      ),
      GoRoute(
        name: AppRoutes.editSearchTaskName,
        path: AppRoutes.editSearchTaskPath,
        builder: (context, state) => TaskFormScreen(
          taskId: state.pathParameters[AppRoutes.taskIdParameter],
        ),
      ),
      GoRoute(
        name: AppRoutes.profileName,
        path: AppRoutes.profilePath,
        builder: (context, state) => const MainNavigationScreen(
          initialIndex: AppConstants.profileTabIndex,
        ),
      ),
      GoRoute(
        name: AppRoutes.settingsName,
        path: AppRoutes.settingsPath,
        builder: (context, state) => const MainNavigationScreen(
          initialIndex: AppConstants.settingsTabIndex,
        ),
      ),
      GoRoute(
        name: AppRoutes.notificationSettingsName,
        path: AppRoutes.notificationSettingsPath,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        name: AppRoutes.dataRefreshSettingsName,
        path: AppRoutes.dataRefreshSettingsPath,
        builder: (context, state) => const DataRefreshSettingsScreen(),
      ),
      GoRoute(
        name: AppRoutes.dailyReportName,
        path: AppRoutes.dailyReportPath,
        builder: (context, state) => const MainNavigationScreen(
          initialIndex: AppConstants.dailyReportTabIndex,
        ),
      ),
      GoRoute(
        name: AppRoutes.applicationTrackerName,
        path: AppRoutes.applicationTrackerPath,
        builder: (context, state) => const MainNavigationScreen(
          initialIndex: AppConstants.applicationTrackerTabIndex,
        ),
      ),
      GoRoute(
        name: AppRoutes.profileOptimizerName,
        path: AppRoutes.profileOptimizerPath,
        builder: (context, state) => const MainNavigationScreen(
          initialIndex: AppConstants.profileOptimizerTabIndex,
        ),
      ),
    ],
  );
});
