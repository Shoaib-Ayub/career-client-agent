import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/storage/local_model.dart';
import 'package:career_client_agent/core/storage/models/opportunity_model_decoder.dart';
import 'package:career_client_agent/core/storage/models/opportunity_result.dart';
import 'package:career_client_agent/features/opportunities/model/opportunity_freshness.dart';

class ClientLeadModel implements LocalModel, OpportunityResult {
  const ClientLeadModel({
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
    this.leadCategory = AppStrings.emptyValue,
    this.budget = AppStrings.emptyValue,
    this.budgetType = AppStrings.emptyValue,
    this.country = AppStrings.emptyValue,
    this.platform = AppStrings.emptyValue,
    this.proposalUrl = AppStrings.emptyValue,
    this.leadScore = AppConstants.zeroScore,
    this.whyGoodLead = const [],
    this.suggestedMessage = AppStrings.emptyValue,
    this.shortMessage = AppStrings.emptyValue,
    this.manualAction = AppStrings.emptyValue,
    this.expectedLeadType = AppStrings.emptyValue,
    this.searchKeyword = AppStrings.emptyValue,
    this.platformProjectId = AppStrings.emptyValue,
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
  final String leadCategory;
  final String budget;
  final String budgetType;
  final String country;
  final String platform;
  final String proposalUrl;
  final int leadScore;
  final List<String> whyGoodLead;
  final String suggestedMessage;
  final String shortMessage;
  final String manualAction;
  final String expectedLeadType;
  final String searchKeyword;
  final String platformProjectId;

  factory ClientLeadModel.fromMap(Map<dynamic, dynamic> map) {
    final now = DateTime.now();
    return ClientLeadModel(
      id: map['id'] as String,
      title:
          (map['title'] ?? map['service'] ?? AppStrings.clientLeadsTitle)
              as String,
      organization:
          (map['organization'] ??
                  map['company'] ??
                  map['name'] ??
                  AppStrings.appName)
              as String,
      location: (map['location'] ?? AppStrings.remoteLocation) as String,
      sourceLink:
          (map['sourceLink'] ?? AppStrings.sampleClientSource) as String,
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
        fallback: [AppStrings.mockSkillFlutter],
      ),
      matchScore: OpportunityModelDecoder.score(map['matchScore']),
      fresherFriendly: OpportunityModelDecoder.boolean(
        map['fresherFriendly'],
        fallback: true,
      ),
      visaSponsorship: OpportunityModelDecoder.boolean(map['visaSponsorship']),
      trainingProvided: OpportunityModelDecoder.boolean(
        map['trainingProvided'],
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
      leadCategory: (map['leadCategory'] ?? AppStrings.emptyValue) as String,
      budget: (map['budget'] ?? AppStrings.emptyValue) as String,
      budgetType: (map['budgetType'] ?? AppStrings.emptyValue) as String,
      country: (map['country'] ?? AppStrings.emptyValue) as String,
      platform: (map['platform'] ?? AppStrings.emptyValue) as String,
      proposalUrl: (map['proposalUrl'] ?? AppStrings.emptyValue) as String,
      leadScore: OpportunityModelDecoder.score(map['leadScore']),
      whyGoodLead: OpportunityModelDecoder.strings(map['whyGoodLead']),
      suggestedMessage:
          (map['suggestedMessage'] ?? AppStrings.emptyValue) as String,
      shortMessage: (map['shortMessage'] ?? AppStrings.emptyValue) as String,
      manualAction: (map['manualAction'] ?? AppStrings.emptyValue) as String,
      expectedLeadType:
          (map['expectedLeadType'] ?? AppStrings.emptyValue) as String,
      searchKeyword: (map['searchKeyword'] ?? AppStrings.emptyValue) as String,
      platformProjectId:
          (map['platformProjectId'] ?? AppStrings.emptyValue) as String,
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
    'leadCategory': leadCategory,
    'budget': budget,
    'budgetType': budgetType,
    'country': country,
    'platform': platform,
    'proposalUrl': proposalUrl,
    'leadScore': leadScore,
    'whyGoodLead': whyGoodLead,
    'suggestedMessage': suggestedMessage,
    'shortMessage': shortMessage,
    'manualAction': manualAction,
    'expectedLeadType': expectedLeadType,
    'searchKeyword': searchKeyword,
    'platformProjectId': platformProjectId,
  };
}
