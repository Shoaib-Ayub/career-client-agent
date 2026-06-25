import 'package:career_client_agent/app/view_model/app_navigation_view_model.dart';
import 'package:career_client_agent/core/widgets/app_navigation_drawer.dart';
import 'package:career_client_agent/core/widgets/app_scaffold.dart';
import 'package:career_client_agent/features/client_leads/view/client_leads_screen.dart';
import 'package:career_client_agent/features/application_tracker/view/application_tracker_screen.dart';
import 'package:career_client_agent/features/dashboard/view/dashboard_screen.dart';
import 'package:career_client_agent/features/daily_report/view/daily_report_screen.dart';
import 'package:career_client_agent/features/government_jobs/view/government_jobs_screen.dart';
import 'package:career_client_agent/features/jobs/view/jobs_screen.dart';
import 'package:career_client_agent/features/profile/view/profile_screen.dart';
import 'package:career_client_agent/features/profile_optimizer/view/profile_optimizer_screen.dart';
import 'package:career_client_agent/features/scholarships/view/scholarships_screen.dart';
import 'package:career_client_agent/features/search_tasks/view/search_tasks_screen.dart';
import 'package:career_client_agent/features/settings/view/settings_overview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({required this.initialIndex, super.key});

  final int initialIndex;

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  static const _screens = <Widget>[
    DashboardScreen(),
    JobsScreen(),
    ScholarshipsScreen(),
    SearchTasksScreen(),
    ClientLeadsScreen(),
    GovernmentJobsScreen(),
    ProfileScreen(),
    SettingsOverviewScreen(),
    DailyReportScreen(),
    ApplicationTrackerScreen(),
    ProfileOptimizerScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _synchronizeSelectedPage();
  }

  @override
  void didUpdateWidget(covariant MainNavigationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialIndex != widget.initialIndex) {
      _synchronizeSelectedPage();
    }
  }

  void _synchronizeSelectedPage() {
    if (ref.read(appNavigationViewModelProvider) == widget.initialIndex) {
      return;
    }

    Future<void>.microtask(() {
      if (mounted) {
        ref
            .read(appNavigationViewModelProvider.notifier)
            .selectPage(widget.initialIndex);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedPageIndex = ref.watch(appNavigationViewModelProvider);
    final viewModel = ref.watch(appNavigationViewModelProvider.notifier);
    final bottomDestinations = viewModel.bottomDestinations;
    final currentDestination = viewModel.destinationForPage(selectedPageIndex);

    return AppScaffold(
      title: currentDestination.label,
      selectedIndex: viewModel.bottomIndexForPage(selectedPageIndex),
      destinations: bottomDestinations,
      onDestinationSelected: (bottomIndex) async {
        final destination = bottomDestinations[bottomIndex];
        await _openDestination(destination);
      },
      drawer: AppNavigationDrawer(
        destinations: viewModel.drawerDestinations,
        selectedPageIndex: selectedPageIndex,
        onDestinationSelected: (destination) async {
          Navigator.of(context).pop();
          await _openDestination(destination);
        },
      ),
      body: _screens[selectedPageIndex],
    );
  }

  Future<void> _openDestination(AppNavigationDestination destination) async {
    final viewModel = ref.read(appNavigationViewModelProvider.notifier);
    final currentPageIndex = ref.read(appNavigationViewModelProvider);

    if (currentPageIndex == destination.pageIndex) {
      return;
    }

    viewModel.selectPage(destination.pageIndex);
    await context.pushNamed(destination.routeName);

    if (mounted) {
      viewModel.selectPage(widget.initialIndex);
    }
  }
}
