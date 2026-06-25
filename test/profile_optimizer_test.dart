import 'dart:io';

import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/storage/local_storage_service.dart';
import 'package:career_client_agent/features/profile/model/user_profile.dart';
import 'package:career_client_agent/features/profile_optimizer/model/platform_links.dart';
import 'package:career_client_agent/features/profile_optimizer/repository/profile_optimizer_repository.dart';
import 'package:career_client_agent/features/profile_optimizer/service/profile_optimizer_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory hiveDirectory;
  late ProfileOptimizerRepository repository;

  setUp(() async {
    hiveDirectory = await Directory.systemTemp.createTemp();
    Hive.init(hiveDirectory.path);
    repository = ProfileOptimizerRepository(const LocalStorageService());
  });

  tearDown(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('stores platform links locally using Hive', () async {
    const links = PlatformLinks(
      linkedIn: AppStrings.sampleLinkedInLink,
      github: AppStrings.sampleGitHubLink,
      portfolio: AppStrings.samplePortfolioLink,
      kaggle: AppStrings.sampleKaggleLink,
    );

    await repository.saveLinks(links);
    final saved = await repository.getLinks();

    expect(saved.linkedIn, links.linkedIn);
    expect(saved.github, links.github);
    expect(saved.portfolio, links.portfolio);
    expect(saved.kaggle, links.kaggle);
  });

  test('generates copy-ready suggestions from profile and goals', () {
    const profile = UserProfile(
      name: AppStrings.profilePlaceholderName,
      education: AppStrings.mockProfileEducation,
      cgpa: AppConstants.defaultCgpa,
      skills: [
        AppStrings.mockSkillFlutter,
        AppStrings.mockSkillDart,
        AppStrings.mockSkillGit,
      ],
      location: AppStrings.mockProfileLocation,
      careerGoals: AppStrings.mockProfileCareerGoals,
      preferredCountries: [AppStrings.mockCountryGermany],
      preferredJobTypes: [AppStrings.mockJobTypeFullTime],
      experienceYears: AppConstants.defaultExperienceYears,
    );

    final result = const ProfileOptimizerService().generate(profile);

    expect(result.linkedInHeadline, contains(AppStrings.mockSkillFlutter));
    expect(result.aboutSectionDraft, contains(profile.careerGoals));
    expect(result.skillsToAdd, isNotEmpty);
    expect(result.featuredProjectsOrder, hasLength(3));
    expect(result.projectDescriptions, hasLength(3));
    expect(result.recruiterMessageTemplate, contains(profile.name));
    expect(result.githubReadmeSuggestions, isNotEmpty);
    expect(result.portfolioHeroSection, contains(profile.name));
  });
}
