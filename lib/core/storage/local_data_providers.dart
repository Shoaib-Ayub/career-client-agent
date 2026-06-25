import 'package:career_client_agent/core/storage/models/client_lead_model.dart';
import 'package:career_client_agent/core/storage/models/government_job_model.dart';
import 'package:career_client_agent/core/storage/models/job_model.dart';
import 'package:career_client_agent/core/storage/models/scholarship_model.dart';
import 'package:career_client_agent/core/storage/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final storedJobsProvider = FutureProvider<List<JobModel>>((ref) {
  return ref.watch(jobsRepositoryProvider).getAll();
});

final storedScholarshipsProvider = FutureProvider<List<ScholarshipModel>>((
  ref,
) {
  return ref.watch(scholarshipsRepositoryProvider).getAll();
});

final storedGovernmentJobsProvider = FutureProvider<List<GovernmentJobModel>>((
  ref,
) {
  return ref.watch(governmentJobsRepositoryProvider).getAll();
});

final storedClientLeadsProvider = FutureProvider<List<ClientLeadModel>>((ref) {
  return ref.watch(clientLeadsRepositoryProvider).getAll();
});
