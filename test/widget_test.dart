import 'dart:io';

import 'package:career_client_agent/app/app.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/constants/app_sizes.dart';
import 'package:career_client_agent/core/storage/local_database_service.dart';
import 'package:career_client_agent/core/storage/local_storage_service.dart';
import 'package:career_client_agent/core/storage/repository_providers.dart';
import 'package:career_client_agent/features/client_leads/repository/client_leads_repository.dart';
import 'package:career_client_agent/features/dashboard/service/dashboard_snapshot_service.dart';
import 'package:career_client_agent/features/government_jobs/repository/government_jobs_repository.dart';
import 'package:career_client_agent/features/jobs/repository/jobs_repository.dart';
import 'package:career_client_agent/features/scholarships/repository/scholarships_repository.dart';
import 'package:career_client_agent/features/splash/view_model/splash_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp();
    Hive.init(hiveDirectory.path);
    await const LocalDatabaseService().seedInitialData();
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  testWidgets('moves from splash to dashboard', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          splashViewModelProvider.overrideWithValue(
            const SplashViewModel(duration: Duration.zero),
          ),
          jobsRepositoryProvider.overrideWithValue(
            JobsRepository(const LocalStorageService()),
          ),
          scholarshipsRepositoryProvider.overrideWithValue(
            ScholarshipsRepository(const LocalStorageService()),
          ),
          governmentJobsRepositoryProvider.overrideWithValue(
            GovernmentJobsRepository(const LocalStorageService()),
          ),
          clientLeadsRepositoryProvider.overrideWithValue(
            ClientLeadsRepository(const LocalStorageService()),
          ),
          dashboardSnapshotServiceProvider.overrideWithValue(
            _MemoryDashboardSnapshotStore(),
          ),
        ],
        child: const CareerClientAgentApp(),
      ),
    );

    expect(find.text(AppStrings.appName), findsOneWidget);

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await _pumpUntilFound(tester, find.text(AppStrings.dashboardDataTitle));

    expect(find.text(AppStrings.dashboardTitle), findsWidgets);
    expect(find.text(AppStrings.dashboardDataTitle), findsOneWidget);
    expect(find.text(AppStrings.jobsTitle), findsOneWidget);

    await tester.tap(find.text(AppStrings.jobsTitle));
    await _pumpUntilFound(tester, find.text(AppStrings.jobsResultsSubtitle));

    expect(find.text(AppStrings.jobsResultsSubtitle), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byTooltip(AppStrings.openNavigationMenu));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.scrollUntilVisible(
      find.text(AppStrings.settingsTitle),
      AppSizes.bottomNavigationHeight,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text(AppStrings.settingsTitle));
    await _pumpUntilFound(tester, find.text(AppStrings.settingsOverviewTitle));

    expect(find.text(AppStrings.settingsOverviewTitle), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await _pumpUntilFound(tester, find.text(AppStrings.jobsResultsSubtitle));

    expect(find.text(AppStrings.jobsResultsSubtitle), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await _pumpUntilFound(tester, find.text(AppStrings.dashboardDataTitle));

    expect(find.text(AppStrings.dashboardDataTitle), findsOneWidget);
  });
}

class _MemoryDashboardSnapshotStore implements DashboardSnapshotStore {
  DashboardSnapshot snapshot = const DashboardSnapshot(opportunityIds: {});

  @override
  Future<DashboardSnapshot> read() async => snapshot;

  @override
  Future<void> save({
    required Set<String> opportunityIds,
    required DateTime updatedAt,
  }) async {
    snapshot = DashboardSnapshot(
      opportunityIds: opportunityIds,
      updatedAt: updatedAt,
    );
  }
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 500));
      return;
    }
  }
  final visibleText = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data)
      .whereType<String>()
      .join(' | ');
  fail('Expected widget was not found. Visible text: $visibleText');
}
