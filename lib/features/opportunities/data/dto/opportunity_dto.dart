class OpportunityDto {
  const OpportunityDto({
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
    required this.foundAt,
    required this.sourceName,
    required this.freshnessStatus,
    this.leadCategory = '',
    this.budget = '',
    this.budgetType = '',
    this.country = '',
    this.platform = '',
    this.proposalUrl = '',
    this.leadScore = 0,
    this.whyGoodLead = const [],
    this.suggestedMessage = '',
    this.shortMessage = '',
    this.manualAction = '',
    this.expectedLeadType = '',
    this.searchKeyword = '',
    this.platformProjectId = '',
    this.qualificationRequired = '',
    this.domicileRequired = '',
    this.provinceEligibility = '',
    this.eligibilityReason = '',
    this.advertisementNumber = '',
    this.postCount,
    this.jobScale = '',
    this.forceCategory = '',
  });

  final String id;
  final String title;
  final String organization;
  final String location;
  final String sourceLink;
  final String postedDate;
  final String deadline;
  final List<String> requiredSkills;
  final int matchScore;
  final bool fresherFriendly;
  final bool visaSponsorship;
  final bool trainingProvided;
  final List<String> whyMatch;
  final List<String> cvSuggestions;
  final String foundAt;
  final String sourceName;
  final String freshnessStatus;
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
  final String qualificationRequired;
  final String domicileRequired;
  final String provinceEligibility;
  final String eligibilityReason;
  final String advertisementNumber;
  final int? postCount;
  final String jobScale;
  final String forceCategory;

  factory OpportunityDto.fromJson(Map<String, dynamic> json) {
    final sourceLink =
        (json['source_link'] ??
                json['sourceLink'] ??
                json['apply_url'] ??
                json['apply_link'] ??
                '')
            .toString();
    final eligibilityReason =
        (json['eligibility_reason'] ?? json['eligibilityReason'] ?? '')
            .toString();
    return OpportunityDto(
      id: _localId(json['id']?.toString(), sourceLink),
      title: (json['title'] ?? '').toString(),
      organization: (json['organization'] ?? json['department'] ?? '')
          .toString(),
      location: (json['location'] ?? json['province_city'] ?? '').toString(),
      sourceLink: sourceLink,
      postedDate: (json['posted_date'] ?? json['postedDate'] ?? '').toString(),
      deadline:
          (json['deadline'] ??
                  json['application_deadline'] ??
                  json['applicationDeadline'] ??
                  '')
              .toString(),
      requiredSkills: List<String>.from(
        (json['skills'] ?? json['requiredSkills']) as List? ?? const [],
      ),
      matchScore: (json['match_score'] ?? json['matchScore']) as int? ?? 0,
      fresherFriendly:
          (json['fresher_friendly'] ?? json['fresherFriendly']) as bool? ??
          false,
      visaSponsorship:
          (json['visa_sponsorship'] ?? json['visaSponsorship']) as bool? ??
          false,
      trainingProvided:
          (json['training_provided'] ?? json['trainingProvided']) as bool? ??
          false,
      whyMatch: _strings(
        json['why_match'] ??
            json['whyMatch'] ??
            json['match_reason'] ??
            eligibilityReason,
      ),
      cvSuggestions: List<String>.from(
        (json['cv_suggestions'] ?? json['cvSuggestions']) as List? ?? const [],
      ),
      foundAt: (json['found_at'] ?? json['foundAt'] ?? '').toString(),
      sourceName:
          (json['source_name'] ?? json['sourceName'] ?? json['source'] ?? '')
              .toString(),
      freshnessStatus:
          (json['freshness_status'] ?? json['freshnessStatus'] ?? 'unknown')
              .toString(),
      leadCategory: (json['lead_category'] ?? json['leadCategory'] ?? '')
          .toString(),
      budget: (json['budget'] ?? '').toString(),
      budgetType: (json['budget_type'] ?? json['budgetType'] ?? '').toString(),
      country: (json['country'] ?? json['client_country'] ?? '').toString(),
      platform: (json['platform'] ?? json['client_platform'] ?? '').toString(),
      proposalUrl:
          (json['proposal_url'] ??
                  json['proposalUrl'] ??
                  json['apply_link'] ??
                  '')
              .toString(),
      leadScore: _integer(json['lead_score'] ?? json['leadScore']),
      whyGoodLead: List<String>.from(
        (json['why_good_lead'] ??
                    json['whyGoodLead'] ??
                    json['why_this_is_good'])
                as List? ??
            const [],
      ),
      suggestedMessage:
          (json['suggested_message'] ?? json['suggestedMessage'] ?? '')
              .toString(),
      shortMessage: (json['short_message'] ?? json['shortMessage'] ?? '')
          .toString(),
      manualAction: (json['manual_action'] ?? json['manualAction'] ?? '')
          .toString(),
      expectedLeadType:
          (json['expected_lead_type'] ?? json['expectedLeadType'] ?? '')
              .toString(),
      searchKeyword: (json['search_keyword'] ?? json['searchKeyword'] ?? '')
          .toString(),
      platformProjectId:
          (json['platform_project_id'] ?? json['platformProjectId'] ?? '')
              .toString(),
      qualificationRequired:
          (json['qualification_required'] ??
                  json['qualification'] ??
                  json['required_education'] ??
                  '')
              .toString(),
      domicileRequired:
          (json['domicile_required'] ?? json['eligibility_domicile'] ?? '')
              .toString(),
      provinceEligibility: (json['province_eligibility'] ?? '').toString(),
      eligibilityReason: eligibilityReason,
      advertisementNumber: (json['advertisement_number'] ?? '').toString(),
      postCount: _nullableInteger(json['post_count']),
      jobScale: (json['job_scale'] ?? json['grade'] ?? '').toString(),
      forceCategory: (json['force_category'] ?? '').toString(),
    );
  }

  static String _localId(String? id, String sourceLink) {
    if (id != null && id.isNotEmpty && id.length <= 255) {
      return id;
    }

    var hash = 0x811C9DC5;
    for (final codeUnit in sourceLink.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static int _integer(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _nullableInteger(Object? value) {
    if (value == null) {
      return null;
    }
    return _integer(value);
  }

  static List<String> _strings(Object? value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? const [] : [text];
  }
}
