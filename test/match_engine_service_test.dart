import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/features/jobs/data/mock_jobs.dart';
import 'package:career_client_agent/features/jobs/service/match_engine_service.dart';
import 'package:career_client_agent/features/profile/model/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = MatchEngineService();

  test('calculates the featured job match and missing skills', () {
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

    final result = engine.calculate(profile: profile, job: MockJobs.featured);

    expect(result.overallScore, 84);
    expect(
      result.missingSkills,
      containsAll([AppStrings.mockSkillRestApis, AppStrings.mockSkillRiverpod]),
    );
  });
}
