import 'dart:io';

import 'package:career_client_agent/app/app.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/constants/app_sizes.dart';
import 'package:career_client_agent/core/storage/local_database_service.dart';
import 'package:career_client_agent/core/storage/local_storage_service.dart';
import 'package:career_client_agent/core/storage/models/client_lead_model.dart';
import 'package:career_client_agent/core/storage/models/government_job_model.dart';
import 'package:career_client_agent/core/storage/models/job_model.dart';
import 'package:career_client_agent/core/storage/models/scholarship_model.dart';
import 'package:career_client_agent/core/storage/repository_providers.dart';
import 'package:career_client_agent/features/client_leads/repository/client_leads_repository.dart';
import 'package:career_client_agent/features/dashboard/model/dashboard_state.dart';
import 'package:career_client_agent/features/dashboard/service/dashboard_snapshot_service.dart';
import 'package:career_client_agent/features/dashboard/view_model/dashboard_view_model.dart';
import 'package:career_client_agent/features/government_jobs/repository/government_jobs_repository.dart';
import 'package:career_client_agent/features/jobs/repository/jobs_repository.dart';
import 'package:career_client_agent/features/jobs/view_model/jobs_view_model.dart';
import 'package:career_client_agent/features/opportunities/model/opportunity_filter.dart';
import 'package:career_client_agent/features/opportunities/model/opportunity_list_state.dart';
import 'package:career_client_agent/features/opportunities/model/opportunity_freshness.dart';
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
          dashboardViewModelProvider.overrideWith(_FakeDashboardViewModel.new),
          jobsViewModelProvider.overrideWith(_FakeJobsViewModel.new),
          jobsRepositoryProvider.overrideWithValue(
            _FakeJobsRepository([_job()]),
          ),
          scholarshipsRepositoryProvider.overrideWithValue(
            _FakeScholarshipsRepository([_scholarship()]),
          ),
          governmentJobsRepositoryProvider.overrideWithValue(
            _FakeGovernmentJobsRepository([_governmentJob()]),
          ),
          clientLeadsRepositoryProvider.overrideWithValue(
            _FakeClientLeadsRepository([_clientLead()]),
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
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
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
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
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

class _FakeDashboardViewModel extends DashboardViewModel {
  @override
  Future<DashboardState> build() async {
    return DashboardState(
      jobs: 1,
      scholarships: 1,
      governmentJobs: 1,
      clientLeads: 1,
      todayTotal: 4,
      newSinceLastRun: 4,
      lastUpdatedAt: _today,
    );
  }
}

class _FakeJobsViewModel extends JobsViewModel {
  @override
  Future<OpportunityListState<JobModel>> build() async {
    return OpportunityListState(
      items: [_job()],
      selectedFilter: OpportunityFilter.latest,
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

class _FakeJobsRepository extends JobsRepository {
  _FakeJobsRepository(this.items) : super(const LocalStorageService());

  final List<JobModel> items;

  @override
  Future<List<JobModel>> getAll() async => items;

  @override
  Future<List<JobModel>> fetchLatest() async => items;
}

class _FakeScholarshipsRepository extends ScholarshipsRepository {
  _FakeScholarshipsRepository(this.items) : super(const LocalStorageService());

  final List<ScholarshipModel> items;

  @override
  Future<List<ScholarshipModel>> getAll() async => items;

  @override
  Future<List<ScholarshipModel>> fetchLatest() async => items;
}

class _FakeGovernmentJobsRepository extends GovernmentJobsRepository {
  _FakeGovernmentJobsRepository(this.items)
    : super(const LocalStorageService());

  final List<GovernmentJobModel> items;

  @override
  Future<List<GovernmentJobModel>> getAll() async => items;

  @override
  Future<List<GovernmentJobModel>> fetchLatest() async => items;
}

class _FakeClientLeadsRepository extends ClientLeadsRepository {
  _FakeClientLeadsRepository(this.items) : super(const LocalStorageService());

  final List<ClientLeadModel> items;

  @override
  Future<List<ClientLeadModel>> getAll() async => items;

  @override
  Future<List<ClientLeadModel>> fetchLatest() async => items;
}

DateTime get _today => DateTime(2026, 7);

JobModel _job() => JobModel(
  id: 'job',
  title: AppStrings.mockJobTitle,
  organization: AppStrings.mockJobCompany,
  location: AppStrings.remoteLocation,
  sourceLink: AppStrings.sampleJobSource,
  postedDate: _today,
  deadline: _today.add(const Duration(days: 30)),
  requiredSkills: const [AppStrings.mockSkillFlutter],
  matchScore: 90,
  fresherFriendly: true,
  visaSponsorship: false,
  trainingProvided: false,
  whyMatch: const [],
  cvSuggestions: const [],
  requiredEducation: AppStrings.mockJobEducation,
  minimumExperienceYears: 0,
  jobType: AppStrings.mockJobTypeRemote,
  freshnessStatus: OpportunityFreshness.today,
);

ScholarshipModel _scholarship() => ScholarshipModel(
  id: 'scholarship',
  title: AppStrings.sampleScholarshipTitle,
  organization: AppStrings.sampleScholarshipProvider,
  location: AppStrings.globalLocation,
  sourceLink: AppStrings.sampleScholarshipSource,
  postedDate: _today,
  deadline: _today.add(const Duration(days: 30)),
  requiredSkills: const [AppStrings.sampleScholarshipField],
  matchScore: 90,
  fresherFriendly: true,
  visaSponsorship: true,
  trainingProvided: true,
  whyMatch: const [],
  cvSuggestions: const [],
  freshnessStatus: OpportunityFreshness.today,
);

GovernmentJobModel _governmentJob() => GovernmentJobModel(
  id: 'government-job',
  title: AppStrings.sampleGovernmentJobTitle,
  organization: AppStrings.sampleGovernmentDepartment,
  location: AppStrings.pakistanPunjabLocation,
  sourceLink: AppStrings.sampleGovernmentSource,
  postedDate: _today,
  deadline: _today.add(const Duration(days: 30)),
  requiredSkills: const [],
  matchScore: 90,
  fresherFriendly: true,
  visaSponsorship: false,
  trainingProvided: false,
  whyMatch: const [],
  cvSuggestions: const [],
  freshnessStatus: OpportunityFreshness.today,
);

ClientLeadModel _clientLead() => ClientLeadModel(
  id: 'client-lead',
  title: AppStrings.sampleClientService,
  organization: AppStrings.sampleClientCompany,
  location: AppStrings.remoteLocation,
  sourceLink: AppStrings.sampleClientSource,
  postedDate: _today,
  deadline: _today.add(const Duration(days: 30)),
  requiredSkills: const [AppStrings.mockSkillFlutter],
  matchScore: 90,
  fresherFriendly: true,
  visaSponsorship: false,
  trainingProvided: false,
  whyMatch: const [],
  cvSuggestions: const [],
  freshnessStatus: OpportunityFreshness.today,
);
