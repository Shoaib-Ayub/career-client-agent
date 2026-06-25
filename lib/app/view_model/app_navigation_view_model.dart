import 'package:career_client_agent/app/routes/app_routes.dart';
import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_icons.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appNavigationViewModelProvider =
    NotifierProvider<AppNavigationViewModel, int>(AppNavigationViewModel.new);

class AppNavigationViewModel extends Notifier<int> {
  @override
  int build() => AppConstants.dashboardTabIndex;

  void selectPage(int index) {
    state = index;
  }

  List<AppNavigationDestination> get bottomDestinations => const [
    AppNavigationDestination(
      pageIndex: AppConstants.dashboardTabIndex,
      label: AppStrings.dashboardTitle,
      icon: AppIcons.dashboard,
      routeName: AppRoutes.dashboardName,
    ),
    AppNavigationDestination(
      pageIndex: AppConstants.jobsTabIndex,
      label: AppStrings.jobsTitle,
      icon: AppIcons.jobs,
      routeName: AppRoutes.jobsName,
    ),
    AppNavigationDestination(
      pageIndex: AppConstants.scholarshipsTabIndex,
      label: AppStrings.scholarshipsTitle,
      icon: AppIcons.scholarships,
      routeName: AppRoutes.scholarshipsName,
    ),
    AppNavigationDestination(
      pageIndex: AppConstants.tasksTabIndex,
      label: AppStrings.tasksNavLabel,
      icon: AppIcons.searchTasks,
      routeName: AppRoutes.searchTasksName,
    ),
    AppNavigationDestination(
      pageIndex: AppConstants.clientsTabIndex,
      label: AppStrings.clientsNavLabel,
      icon: AppIcons.clientLeads,
      routeName: AppRoutes.clientLeadsName,
    ),
  ];

  List<AppNavigationDestination> get drawerDestinations => const [
    AppNavigationDestination(
      pageIndex: AppConstants.profileOptimizerTabIndex,
      label: AppStrings.profileOptimizerTitle,
      icon: AppIcons.profileOptimizer,
      routeName: AppRoutes.profileOptimizerName,
    ),
    AppNavigationDestination(
      pageIndex: AppConstants.applicationTrackerTabIndex,
      label: AppStrings.applicationTrackerTitle,
      icon: AppIcons.applicationTracker,
      routeName: AppRoutes.applicationTrackerName,
    ),
    AppNavigationDestination(
      pageIndex: AppConstants.dailyReportTabIndex,
      label: AppStrings.dailyReportTitle,
      icon: AppIcons.dailyReport,
      routeName: AppRoutes.dailyReportName,
    ),
    AppNavigationDestination(
      pageIndex: AppConstants.governmentJobsTabIndex,
      label: AppStrings.governmentJobsTitle,
      icon: AppIcons.governmentJobs,
      routeName: AppRoutes.governmentJobsName,
    ),
    AppNavigationDestination(
      pageIndex: AppConstants.profileTabIndex,
      label: AppStrings.profileTitle,
      icon: AppIcons.profile,
      routeName: AppRoutes.profileName,
    ),
    AppNavigationDestination(
      pageIndex: AppConstants.settingsTabIndex,
      label: AppStrings.settingsTitle,
      icon: AppIcons.settings,
      routeName: AppRoutes.settingsName,
    ),
  ];

  List<AppNavigationDestination> get allDestinations => [
    ...bottomDestinations,
    ...drawerDestinations,
  ];

  AppNavigationDestination destinationForPage(int pageIndex) {
    return allDestinations.firstWhere(
      (destination) => destination.pageIndex == pageIndex,
    );
  }

  int? bottomIndexForPage(int pageIndex) {
    final index = bottomDestinations.indexWhere(
      (destination) => destination.pageIndex == pageIndex,
    );

    return index < AppConstants.dashboardTabIndex ? null : index;
  }
}

@immutable
class AppNavigationDestination {
  const AppNavigationDestination({
    required this.pageIndex,
    required this.label,
    required this.icon,
    required this.routeName,
  });

  final int pageIndex;
  final String label;
  final IconData icon;
  final String routeName;
}
