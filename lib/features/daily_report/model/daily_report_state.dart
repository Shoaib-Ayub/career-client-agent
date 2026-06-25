import 'package:career_client_agent/features/opportunities/model/opportunity_filter.dart';

class DailyReportState {
  const DailyReportState({
    required this.jobs,
    required this.scholarships,
    required this.governmentJobs,
    required this.clientLeads,
    required this.selectedFilter,
    this.isRefreshing = false,
  });

  final int jobs;
  final int scholarships;
  final int governmentJobs;
  final int clientLeads;
  final OpportunityFilter selectedFilter;
  final bool isRefreshing;

  int get total => jobs + scholarships + governmentJobs + clientLeads;
  bool get isEmpty => total == 0;

  DailyReportState copyWith({
    bool? isRefreshing,
    OpportunityFilter? selectedFilter,
  }) {
    return DailyReportState(
      jobs: jobs,
      scholarships: scholarships,
      governmentJobs: governmentJobs,
      clientLeads: clientLeads,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}
