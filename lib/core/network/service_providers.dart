import 'package:career_client_agent/core/network/network_providers.dart';
import 'package:career_client_agent/features/client_leads/service/client_leads_service.dart';
import 'package:career_client_agent/features/government_jobs/service/government_jobs_service.dart';
import 'package:career_client_agent/features/jobs/service/jobs_service.dart';
import 'package:career_client_agent/features/scholarships/service/scholarships_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final jobsServiceProvider = Provider<JobsService>((ref) {
  return JobsService(ref.watch(apiClientProvider));
});

final scholarshipsServiceProvider = Provider<ScholarshipsService>((ref) {
  return ScholarshipsService(ref.watch(apiClientProvider));
});

final governmentJobsServiceProvider = Provider<GovernmentJobsService>((ref) {
  return GovernmentJobsService(ref.watch(apiClientProvider));
});

final clientLeadsServiceProvider = Provider<ClientLeadsService>((ref) {
  return ClientLeadsService(ref.watch(apiClientProvider));
});
