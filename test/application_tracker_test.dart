import 'dart:io';

import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/storage/local_storage_service.dart';
import 'package:career_client_agent/core/storage/models/job_model.dart';
import 'package:career_client_agent/core/storage/repository_providers.dart';
import 'package:career_client_agent/features/application_tracker/model/application_tracker_item.dart';
import 'package:career_client_agent/features/application_tracker/repository/application_tracker_repository.dart';
import 'package:career_client_agent/features/application_tracker/service/apply_assistant_service.dart';
import 'package:career_client_agent/features/application_tracker/view_model/application_tracker_view_model.dart';
import 'package:career_client_agent/features/profile/model/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory hiveDirectory;
  late ApplicationTrackerRepository repository;

  setUp(() async {
    hiveDirectory = await Directory.systemTemp.createTemp();
    Hive.init(hiveDirectory.path);
    repository = ApplicationTrackerRepository(const LocalStorageService());
  });

  tearDown(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('saves and updates an application tracker item in Hive', () async {
    final item = _item();
    await repository.saveItem(item);

    expect(await repository.containsOpportunity(item.opportunityId), isTrue);
    expect(await repository.getItems(), hasLength(1));

    await repository.saveItem(
      item.copyWith(
        status: ApplicationStatus.applied,
        appliedDate: DateTime(2026, 6, 23),
        notes: AppStrings.sampleWhyMatch,
        followUpDate: DateTime(2026, 6, 30),
      ),
    );

    final updated = (await repository.getItems()).single;
    expect(updated.status, ApplicationStatus.applied);
    expect(updated.appliedDate, isNotNull);
    expect(updated.notes, AppStrings.sampleWhyMatch);
    expect(updated.followUpDate, isNotNull);
  });

  test('generates local Apply Assistant content', () {
    const profile = UserProfile(
      name: AppStrings.profilePlaceholderName,
      education: AppStrings.mockProfileEducation,
      cgpa: AppConstants.defaultCgpa,
      skills: [AppStrings.mockSkillFlutter],
      location: AppStrings.mockProfileLocation,
      careerGoals: AppStrings.mockProfileCareerGoals,
      preferredCountries: [AppStrings.mockCountryGermany],
      preferredJobTypes: [AppStrings.mockJobTypeFullTime],
      experienceYears: AppConstants.defaultExperienceYears,
    );

    final result = const ApplyAssistantService().generate(
      item: _item(),
      profile: profile,
    );

    expect(result.cvChanges, isNotEmpty);
    expect(result.coverLetterDraft, contains(AppStrings.mockJobTitle));
    expect(result.outreachMessageDraft, contains(AppStrings.mockJobCompany));
    expect(result.requiredDocuments, contains(AppStrings.documentCv));
  });

  test('Riverpod ViewModel prevents duplicate opportunity saves', () async {
    final container = ProviderContainer(
      overrides: [
        applicationTrackerRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await container.read(applicationTrackerViewModelProvider.future);
    final opportunity = JobModel(
      id: AppConstants.sampleJobId,
      title: AppStrings.mockJobTitle,
      organization: AppStrings.mockJobCompany,
      location: AppStrings.mockJobLocation,
      sourceLink: AppStrings.sampleJobSource,
      postedDate: DateTime(2026, 6, 23),
      deadline: DateTime(2026, 7, 23),
      requiredSkills: const [AppStrings.mockSkillFlutter],
      matchScore: AppConstants.defaultMatchScore,
      fresherFriendly: true,
      visaSponsorship: false,
      trainingProvided: true,
      whyMatch: const [AppStrings.sampleWhyMatch],
      cvSuggestions: const [AppStrings.sampleCvSuggestion],
      requiredEducation: AppStrings.mockJobEducation,
      minimumExperienceYears: AppConstants.defaultExperienceYears,
      jobType: AppStrings.mockJobType,
    );
    final viewModel = container.read(
      applicationTrackerViewModelProvider.notifier,
    );

    expect(
      await viewModel.saveOpportunity(
        opportunity: opportunity,
        type: ApplicationType.job,
      ),
      isTrue,
    );
    expect(
      await viewModel.saveOpportunity(
        opportunity: opportunity,
        type: ApplicationType.job,
      ),
      isFalse,
    );
    expect(
      container.read(applicationTrackerViewModelProvider).requireValue,
      hasLength(1),
    );
  });
}

ApplicationTrackerItem _item() {
  return ApplicationTrackerItem(
    id: AppConstants.applicationTrackerBoxName,
    opportunityId: AppConstants.sampleJobId,
    title: AppStrings.mockJobTitle,
    organization: AppStrings.mockJobCompany,
    type: ApplicationType.job,
    sourceLink: AppStrings.sampleJobSource,
    status: ApplicationStatus.saved,
    deadline: DateTime(2026, 7, 23),
    notes: AppStrings.emptyValue,
    requiredSkills: const [
      AppStrings.mockSkillFlutter,
      AppStrings.mockSkillDart,
    ],
    cvSuggestions: const [AppStrings.sampleCvSuggestion],
    savedAt: DateTime(2026, 6, 23),
  );
}
