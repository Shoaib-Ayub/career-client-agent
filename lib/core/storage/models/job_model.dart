import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/storage/local_model.dart';
import 'package:career_client_agent/core/storage/models/opportunity_model_decoder.dart';
import 'package:career_client_agent/core/storage/models/opportunity_result.dart';
import 'package:career_client_agent/features/jobs/model/job.dart';
import 'package:career_client_agent/features/opportunities/model/opportunity_freshness.dart';

class JobModel implements LocalModel, OpportunityResult {
  const JobModel({
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
    required this.requiredEducation,
    required this.minimumExperienceYears,
    required this.jobType,
    DateTime? foundAt,
    this.sourceName = AppStrings.appName,
    this.freshnessStatus = OpportunityFreshness.unknown,
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
  final String requiredEducation;
  final int minimumExperienceYears;
  final String jobType;

  factory JobModel.fromMap(Map<dynamic, dynamic> map) {
    final now = DateTime.now();
    return JobModel(
      id: map['id'] as String,
      title: map['title'] as String,
      organization:
          (map['organization'] ?? map['company'] ?? AppStrings.appName)
              as String,
      location: map['location'] as String,
      sourceLink: (map['sourceLink'] ?? AppStrings.sampleJobSource) as String,
      postedDate: OpportunityModelDecoder.date(
        map['postedDate'],
        fallback: now,
      ),
      deadline: OpportunityModelDecoder.date(
        map['deadline'],
        fallback: now.add(const Duration(days: AppConstants.deadlineSoonDays)),
      ),
      requiredSkills: OpportunityModelDecoder.strings(map['requiredSkills']),
      matchScore: OpportunityModelDecoder.score(map['matchScore']),
      fresherFriendly: OpportunityModelDecoder.boolean(
        map['fresherFriendly'],
        fallback: true,
      ),
      visaSponsorship: OpportunityModelDecoder.boolean(
        map['visaSponsorship'] ?? map['offersVisaSponsorship'],
      ),
      trainingProvided: OpportunityModelDecoder.boolean(
        map['trainingProvided'],
      ),
      whyMatch: OpportunityModelDecoder.whyMatch(map['whyMatch']),
      cvSuggestions: OpportunityModelDecoder.cvSuggestions(
        map['cvSuggestions'],
      ),
      requiredEducation:
          (map['requiredEducation'] ?? AppStrings.mockJobEducation) as String,
      minimumExperienceYears: (map['minimumExperienceYears'] ?? 0) as int,
      jobType: (map['jobType'] ?? AppStrings.mockJobType) as String,
      foundAt: OpportunityModelDecoder.date(map['foundAt'], fallback: now),
      sourceName: (map['sourceName'] ?? AppStrings.appName) as String,
      freshnessStatus: OpportunityFreshness.fromValue(
        map['freshnessStatus'] as String?,
      ),
    );
  }

  Job toDomain() => Job(
    title: title,
    company: organization,
    requiredSkills: requiredSkills,
    requiredEducation: requiredEducation,
    minimumExperienceYears: minimumExperienceYears,
    location: location,
    jobType: jobType,
    offersVisaSponsorship: visaSponsorship,
  );

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
    'requiredEducation': requiredEducation,
    'minimumExperienceYears': minimumExperienceYears,
    'jobType': jobType,
    'foundAt': foundAt.toIso8601String(),
    'sourceName': sourceName,
    'freshnessStatus': freshnessStatus.value,
  };
}
