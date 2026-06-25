import 'dart:io';

import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/storage/local_database_service.dart';
import 'package:career_client_agent/core/storage/local_storage_service.dart';
import 'package:career_client_agent/core/storage/models/job_model.dart';
import 'package:career_client_agent/features/client_leads/repository/client_leads_repository.dart';
import 'package:career_client_agent/features/government_jobs/repository/government_jobs_repository.dart';
import 'package:career_client_agent/features/jobs/repository/jobs_repository.dart';
import 'package:career_client_agent/features/profile/repository/profile_repository.dart';
import 'package:career_client_agent/features/scholarships/repository/scholarships_repository.dart';
import 'package:career_client_agent/features/search_tasks/repository/search_tasks_repository.dart';
import 'package:career_client_agent/features/search_tasks/model/search_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory hiveDirectory;
  late JobsRepository jobs;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp();
    Hive.init(hiveDirectory.path);
    await const LocalDatabaseService().seedInitialData();
    jobs = JobsRepository(const LocalStorageService());
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('seeds every local repository on first launch', () async {
    const storage = LocalStorageService();

    final storedJobs = await jobs.getAll();
    final today = DateTime.now();
    expect(storedJobs, hasLength(2));
    expect(storedJobs.first.postedDate.year, today.year);
    expect(storedJobs.first.postedDate.month, today.month);
    expect(storedJobs.first.postedDate.day, today.day);
    expect(await ScholarshipsRepository(storage).getAll(), hasLength(2));
    expect(await GovernmentJobsRepository(storage).getAll(), hasLength(2));
    expect(await ClientLeadsRepository(storage).getAll(), hasLength(2));
    final tasks = await SearchTasksRepository(storage).getDomainTasks();
    expect(tasks, hasLength(5));
    expect(
      tasks.where((task) => task.taskType == SearchTaskType.job),
      hasLength(2),
    );
    expect(
      tasks
          .firstWhere((task) => task.id == AppConstants.defaultAiJobsTaskId)
          .dailyLimit,
      AppConstants.defaultTaskDailyLimit,
    );
    expect(
      tasks
          .firstWhere((task) => task.id == AppConstants.defaultVisaJobsTaskId)
          .dailyLimit,
      AppConstants.visaTaskDailyLimit,
    );
    expect(
      tasks
          .firstWhere(
            (task) => task.id == AppConstants.defaultScholarshipsTaskId,
          )
          .dailyLimit,
      AppConstants.defaultTaskDailyLimit,
    );
    expect(
      tasks
          .firstWhere(
            (task) => task.id == AppConstants.defaultGovernmentJobsTaskId,
          )
          .dailyLimit,
      AppConstants.governmentTaskDailyLimit,
    );
    expect(
      tasks
          .firstWhere(
            (task) => task.id == AppConstants.defaultClientLeadsTaskId,
          )
          .dailyLimit,
      AppConstants.clientLeadTaskDailyLimit,
    );
    expect(await ProfileRepository(storage).getProfile(), isNotNull);
  });

  test('supports create, read, update, and delete operations', () async {
    final now = DateTime.now();
    final model = JobModel(
      id: AppConstants.taskIdPrefix,
      title: AppStrings.mockJobTitle,
      organization: AppStrings.mockJobCompany,
      location: AppStrings.mockJobLocation,
      sourceLink: AppStrings.sampleJobSource,
      postedDate: now,
      deadline: now.add(const Duration(days: AppConstants.sampleDeadlineDays)),
      requiredSkills: [AppStrings.mockSkillFlutter],
      matchScore: AppConstants.defaultMatchScore,
      fresherFriendly: true,
      visaSponsorship: true,
      trainingProvided: true,
      whyMatch: const [AppStrings.sampleWhyMatch],
      cvSuggestions: const [AppStrings.sampleCvSuggestion],
      requiredEducation: AppStrings.mockJobEducation,
      minimumExperienceYears: AppConstants.defaultExperienceYears,
      jobType: AppStrings.mockJobType,
    );

    await jobs.create(model);
    expect(await jobs.getById(model.id), isNotNull);

    final updated = JobModel(
      id: model.id,
      title: AppStrings.newJobs,
      organization: model.organization,
      location: model.location,
      sourceLink: model.sourceLink,
      postedDate: model.postedDate,
      deadline: model.deadline,
      requiredSkills: model.requiredSkills,
      matchScore: model.matchScore,
      fresherFriendly: model.fresherFriendly,
      visaSponsorship: model.visaSponsorship,
      trainingProvided: model.trainingProvided,
      whyMatch: model.whyMatch,
      cvSuggestions: model.cvSuggestions,
      requiredEducation: model.requiredEducation,
      minimumExperienceYears: model.minimumExperienceYears,
      jobType: model.jobType,
    );
    await jobs.update(updated);
    expect((await jobs.getById(model.id))?.title, AppStrings.newJobs);

    await jobs.delete(model.id);
    expect(await jobs.getById(model.id), isNull);
  });
}
