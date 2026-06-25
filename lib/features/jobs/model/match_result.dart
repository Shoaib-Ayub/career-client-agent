import 'package:flutter/foundation.dart';

@immutable
class MatchResult {
  const MatchResult({
    required this.overallScore,
    required this.skillScore,
    required this.educationScore,
    required this.experienceScore,
    required this.locationScore,
    required this.visaPreferenceScore,
    required this.missingSkills,
    required this.whyMatch,
    required this.suggestedImprovements,
  });

  final int overallScore;
  final int skillScore;
  final int educationScore;
  final int experienceScore;
  final int locationScore;
  final int visaPreferenceScore;
  final List<String> missingSkills;
  final List<String> whyMatch;
  final List<String> suggestedImprovements;
}
