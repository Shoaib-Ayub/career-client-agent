class DashboardState {
  const DashboardState({
    required this.jobs,
    required this.scholarships,
    required this.governmentJobs,
    required this.clientLeads,
    required this.todayTotal,
    required this.newSinceLastRun,
    required this.lastUpdatedAt,
    this.lastSyncTime,
    this.dataSource = '',
    this.recordsDownloaded = 0,
    this.lastSyncStatus = '',
    this.isRefreshing = false,
  });

  final int jobs;
  final int scholarships;
  final int governmentJobs;
  final int clientLeads;
  final int todayTotal;
  final int newSinceLastRun;
  final DateTime lastUpdatedAt;
  final DateTime? lastSyncTime;
  final String dataSource;
  final int recordsDownloaded;
  final String lastSyncStatus;
  final bool isRefreshing;

  bool get isEmpty =>
      jobs == 0 && scholarships == 0 && governmentJobs == 0 && clientLeads == 0;

  DashboardState copyWith({
    int? jobs,
    int? scholarships,
    int? governmentJobs,
    int? clientLeads,
    bool? isRefreshing,
    int? todayTotal,
    int? newSinceLastRun,
    DateTime? lastUpdatedAt,
    DateTime? lastSyncTime,
    String? dataSource,
    int? recordsDownloaded,
    String? lastSyncStatus,
  }) {
    return DashboardState(
      jobs: jobs ?? this.jobs,
      scholarships: scholarships ?? this.scholarships,
      governmentJobs: governmentJobs ?? this.governmentJobs,
      clientLeads: clientLeads ?? this.clientLeads,
      todayTotal: todayTotal ?? this.todayTotal,
      newSinceLastRun: newSinceLastRun ?? this.newSinceLastRun,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      dataSource: dataSource ?? this.dataSource,
      recordsDownloaded: recordsDownloaded ?? this.recordsDownloaded,
      lastSyncStatus: lastSyncStatus ?? this.lastSyncStatus,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}
