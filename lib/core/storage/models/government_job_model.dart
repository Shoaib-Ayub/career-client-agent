import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/storage/local_model.dart';
import 'package:career_client_agent/core/storage/models/opportunity_model_decoder.dart';
import 'package:career_client_agent/core/storage/models/opportunity_result.dart';
import 'package:career_client_agent/features/opportunities/model/opportunity_freshness.dart';

class GovernmentJobModel implements LocalModel, OpportunityResult {
  const GovernmentJobModel({
    required this.id,
    required this.title,
    required this.organization,
    required this.location,
    required this.sourceLink,
    required this.postedDate,
    required this.deadline,
    required this.requiredSkills,
    required this.matchScore,
    required this.fresherFriendly,
    required this.visaSponsorship,
    required this.trainingProvided,
    required this.whyMatch,
    required this.cvSuggestions,
    DateTime? foundAt,
    this.sourceName = AppStrings.appName,
    this.freshnessStatus = OpportunityFreshness.unknown,
    this.qualificationRequired = '',
    this.domicileRequired = '',
    this.provinceEligibility = '',
    this.eligibilityReason = '',
    this.advertisementNumber = '',
    this.postCount,
    this.jobScale = '',
    this.forceCategory = '',
  }) : foundAt = foundAt ?? postedDate;

  @override
  final String id;
  @override
  final String title;
  @override
  final String organization;
  @override
  final String location;
  @override
  final String sourceLink;
  @override
  final DateTime postedDate;
  @override
  final DateTime deadline;
  @override
  final DateTime foundAt;
  @override
  final String sourceName;
  @override
  final OpportunityFreshness freshnessStatus;
  @override
  final List<String> requiredSkills;
  @override
  final int matchScore;
  @override
  final bool fresherFriendly;
  @override
  final bool visaSponsorship;
  @override
  final bool trainingProvided;
  @override
  final List<String> whyMatch;
  @override
  final List<String> cvSuggestions;
  final String qualificationRequired;
  final String domicileRequired;
  final String provinceEligibility;
  final String eligibilityReason;
  final String advertisementNumber;
  final int? postCount;
  final String jobScale;
  final String forceCategory;

  factory GovernmentJobModel.fromMap(Map<dynamic, dynamic> map) {
    final now = DateTime.now();
    return GovernmentJobModel(
      id: map['id'] as String,
      title: map['title'] as String,
      organization:
          (map['organization'] ?? map['department'] ?? AppStrings.appName)
              as String,
      location:
          (map['location'] ?? map['country'] ?? AppStrings.mockProfileLocation)
              as String,
      sourceLink:
          (map['sourceLink'] ?? AppStrings.sampleGovernmentSource) as String,
      postedDate: OpportunityModelDecoder.date(
        map['postedDate'],
        fallback: now,
      ),
      deadline: OpportunityModelDecoder.date(
        map['deadline'],
        fallback: now.add(const Duration(days: AppConstants.deadlineSoonDays)),
      ),
      requiredSkills: OpportunityModelDecoder.strings(
        map['requiredSkills'],
        fallback: [AppStrings.mockSkillDart],
      ),
      matchScore: OpportunityModelDecoder.score(map['matchScore']),
      fresherFriendly: OpportunityModelDecoder.boolean(
        map['fresherFriendly'],
        fallback: true,
      ),
      visaSponsorship: OpportunityModelDecoder.boolean(map['visaSponsorship']),
      trainingProvided: OpportunityModelDecoder.boolean(
        map['trainingProvided'],
        fallback: true,
      ),
      whyMatch: OpportunityModelDecoder.whyMatch(map['whyMatch']),
      cvSuggestions: OpportunityModelDecoder.cvSuggestions(
        map['cvSuggestions'],
      ),
      foundAt: OpportunityModelDecoder.date(map['foundAt'], fallback: now),
      sourceName: (map['sourceName'] ?? AppStrings.appName) as String,
      freshnessStatus: OpportunityFreshness.fromValue(
        map['freshnessStatus'] as String?,
      ),
      qualificationRequired: (map['qualificationRequired'] ?? '').toString(),
      domicileRequired: (map['domicileRequired'] ?? '').toString(),
      provinceEligibility: (map['provinceEligibility'] ?? '').toString(),
      eligibilityReason: (map['eligibilityReason'] ?? '').toString(),
      advertisementNumber: (map['advertisementNumber'] ?? '').toString(),
      postCount: switch (OpportunityModelDecoder.nullableInteger(
        map['postCount'],
      )) {
        final count? when count > 0 => count,
        _ => null,
      },
      jobScale: (map['jobScale'] ?? '').toString(),
      forceCategory: (map['forceCategory'] ?? '').toString(),
    );
  }

  @override
  Map<String, Object> toMap() => {
    'id': id,
    'title': title,
    'organization': organization,
    'location': location,
    'sourceLink': sourceLink,
    'postedDate': postedDate.toIso8601String(),
    'deadline': deadline.toIso8601String(),
    'requiredSkills': requiredSkills,
    'matchScore': matchScore,
    'fresherFriendly': fresherFriendly,
    'visaSponsorship': visaSponsorship,
    'trainingProvided': trainingProvided,
    'whyMatch': whyMatch,
    'cvSuggestions': cvSuggestions,
    'foundAt': foundAt.toIso8601String(),
    'sourceName': sourceName,
    'freshnessStatus': freshnessStatus.value,
    'qualificationRequired': qualificationRequired,
    'domicileRequired': domicileRequired,
    'provinceEligibility': provinceEligibility,
    'eligibilityReason': eligibilityReason,
    'advertisementNumber': advertisementNumber,
    'postCount': postCount ?? 0,
    'jobScale': jobScale,
    'forceCategory': forceCategory,
  };
}
