import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/storage/repository_providers.dart';
import 'package:career_client_agent/features/profile/model/user_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final profileViewModelProvider =
    NotifierProvider<ProfileViewModel, UserProfile>(ProfileViewModel.new);

class ProfileViewModel extends Notifier<UserProfile> {
  @override
  UserProfile build() {
    return ref.read(profileRepositoryProvider).getProfileSync() ??
        _defaultProfile;
  }

  UserProfile get _defaultProfile => const UserProfile(
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
    preferredCountries: [
      AppStrings.mockCountryGermany,
      AppStrings.mockCountryUae,
    ],
    preferredJobTypes: [
      AppStrings.mockJobTypeFullTime,
      AppStrings.mockJobTypeRemote,
    ],
    experienceYears: AppConstants.defaultExperienceYears,
  );

  void save(UserProfile profile) {
    state = profile;
    ref.read(profileRepositoryProvider).saveProfile(profile);
  }

  void saveFromInput({
    required String name,
    required String education,
    required String cgpa,
    required String skills,
    required String location,
    required String careerGoals,
    required String preferredCountries,
    required String preferredJobTypes,
    required String experienceYears,
  }) {
    state = UserProfile(
      name: name.trim(),
      education: education.trim(),
      cgpa: double.tryParse(cgpa.trim()) ?? state.cgpa,
      skills: _parseList(skills),
      location: location.trim(),
      careerGoals: careerGoals.trim(),
      preferredCountries: _parseList(preferredCountries),
      preferredJobTypes: _parseList(preferredJobTypes),
      experienceYears:
          int.tryParse(experienceYears.trim()) ?? state.experienceYears,
    );
    ref.read(profileRepositoryProvider).saveProfile(state);
  }

  List<String> _parseList(String value) {
    return value
        .split(AppConstants.listInputSeparator)
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}
