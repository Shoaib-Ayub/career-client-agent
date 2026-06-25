import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/features/profile/model/user_profile.dart';
import 'package:career_client_agent/features/profile_optimizer/model/profile_optimization.dart';

class ProfileOptimizerService {
  const ProfileOptimizerService();

  ProfileOptimization generate(UserProfile profile) {
    final role = profile.education.trim().isEmpty
        ? AppStrings.optimizerRoleFallback
        : profile.education.trim();
    final skills = profile.skills.isEmpty
        ? const [AppStrings.optimizerSkillsFallback]
        : profile.skills;
    final goal = profile.careerGoals.trim().isEmpty
        ? AppStrings.optimizerGoalFallback
        : profile.careerGoals.trim();
    final countries = profile.preferredCountries.isEmpty
        ? AppStrings.globalLocation
        : profile.preferredCountries.join(AppConstants.listDisplaySeparator);
    final keySkills = skills
        .take(AppConstants.optimizerProjectLimit)
        .toList(growable: false);
    final skillsText = keySkills.join(AppConstants.listDisplaySeparator);

    return ProfileOptimization(
      linkedInHeadline: AppStrings.optimizerHeadline(role, skillsText, goal),
      aboutSectionDraft: AppStrings.optimizerAbout(
        profile.name,
        role,
        skillsText,
        goal,
        countries,
      ),
      skillsToAdd: keySkills.map(AppStrings.optimizerSkillSuggestion).toList(),
      featuredProjectsOrder: [
        for (var index = 0; index < keySkills.length; index++)
          AppStrings.optimizerProjectOrder(index + 1, keySkills[index]),
      ],
      projectDescriptions: keySkills
          .map((skill) => AppStrings.optimizerProjectDescription(skill, goal))
          .toList(),
      recruiterMessageTemplate: AppStrings.optimizerRecruiterMessage(
        profile.name,
        role,
        skillsText,
        goal,
      ),
      githubReadmeSuggestions: const [
        AppStrings.optimizerReadmeProfile,
        AppStrings.optimizerReadmeStack,
        AppStrings.optimizerReadmeProjects,
        AppStrings.optimizerReadmeContact,
      ],
      portfolioHeroSection: AppStrings.optimizerPortfolioHero(
        profile.name,
        role,
        skillsText,
      ),
    );
  }
}
