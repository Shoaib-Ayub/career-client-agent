import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/features/jobs/model/job.dart';

abstract final class MockJobs {
  static const featured = Job(
    title: AppStrings.mockJobTitle,
    company: AppStrings.mockJobCompany,
    requiredSkills: [
      AppStrings.mockSkillFlutter,
      AppStrings.mockSkillDart,
      AppStrings.mockSkillRestApis,
      AppStrings.mockSkillGit,
      AppStrings.mockSkillRiverpod,
    ],
    requiredEducation: AppStrings.mockJobEducation,
    minimumExperienceYears: AppConstants.mockRequiredExperienceYears,
    location: AppStrings.mockJobLocation,
    jobType: AppStrings.mockJobType,
    offersVisaSponsorship: true,
  );

  static const all = [featured];
}
