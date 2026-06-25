import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/features/jobs/model/job.dart';
import 'package:career_client_agent/features/jobs/model/match_result.dart';
import 'package:career_client_agent/features/profile/model/user_profile.dart';

class MatchEngineService {
  const MatchEngineService();

  MatchResult calculate({required UserProfile profile, required Job job}) {
    final normalizedSkills = profile.skills.map(_normalize).toSet();
    final missingSkills = job.requiredSkills
        .where((skill) => !normalizedSkills.contains(_normalize(skill)))
        .toList();
    final matchedSkills = job.requiredSkills.length - missingSkills.length;
    final skillScore = job.requiredSkills.isEmpty
        ? AppConstants.maximumMatchScore
        : ((matchedSkills / job.requiredSkills.length) *
                  AppConstants.maximumMatchScore)
              .round();

    final educationMatches = _educationMatches(
      profile.education,
      job.requiredEducation,
    );
    final educationScore = educationMatches
        ? AppConstants.maximumMatchScore
        : AppConstants.zeroScore;

    final experienceMatches =
        job.minimumExperienceYears <= AppConstants.zeroScore ||
        profile.experienceYears >= job.minimumExperienceYears;
    final experienceScore = experienceMatches
        ? AppConstants.maximumMatchScore
        : ((profile.experienceYears / job.minimumExperienceYears) *
                  AppConstants.maximumMatchScore)
              .clamp(AppConstants.zeroScore, AppConstants.maximumMatchScore)
              .round();

    final preferredCountries = profile.preferredCountries
        .map(_normalize)
        .toSet();
    final locationMatches =
        _normalize(profile.location) == _normalize(job.location) ||
        preferredCountries.contains(_normalize(job.location));
    final locationScore = locationMatches
        ? AppConstants.maximumMatchScore
        : AppConstants.zeroScore;

    final visaMatches =
        _normalize(profile.location) == _normalize(job.location) ||
        job.offersVisaSponsorship;
    final visaScore = visaMatches
        ? AppConstants.maximumMatchScore
        : AppConstants.zeroScore;

    final overallScore =
        ((skillScore * AppConstants.skillMatchWeight) +
            (educationScore * AppConstants.educationMatchWeight) +
            (experienceScore * AppConstants.experienceMatchWeight) +
            (locationScore * AppConstants.locationMatchWeight) +
            (visaScore * AppConstants.visaMatchWeight)) /
        AppConstants.maximumMatchScore;

    final whyMatch = <String>[
      if (skillScore >= AppConstants.positiveMatchThreshold)
        AppStrings.strongSkillAlignment,
      if (educationMatches) AppStrings.educationAligned,
      if (experienceMatches) AppStrings.experienceAligned,
      if (locationMatches) AppStrings.locationAligned,
      if (visaMatches) AppStrings.visaAligned,
    ];

    final improvements = <String>[
      if (missingSkills.isNotEmpty) AppStrings.improveSkills,
      if (!educationMatches) AppStrings.improveEducation,
      if (!experienceMatches) AppStrings.improveExperience,
      if (!locationMatches) AppStrings.improveLocation,
      if (!visaMatches) AppStrings.improveVisa,
    ];

    return MatchResult(
      overallScore: overallScore.round(),
      skillScore: skillScore,
      educationScore: educationScore,
      experienceScore: experienceScore,
      locationScore: locationScore,
      visaPreferenceScore: visaScore,
      missingSkills: missingSkills,
      whyMatch: whyMatch.isEmpty ? [AppStrings.partialMatch] : whyMatch,
      suggestedImprovements: improvements,
    );
  }

  bool _educationMatches(String profileEducation, String requiredEducation) {
    final profile = _normalize(profileEducation);
    final requirement = _normalize(requiredEducation);

    return profile.contains(requirement) ||
        requirement.contains(profile) ||
        (requirement.contains('bachelor') &&
            (profile.contains('bachelor') || profile.startsWith('bs')));
  }

  String _normalize(String value) => value.trim().toLowerCase();
}
