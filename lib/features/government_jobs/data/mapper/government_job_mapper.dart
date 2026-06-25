import 'package:career_client_agent/core/storage/models/government_job_model.dart';
import 'package:career_client_agent/features/government_jobs/data/dto/government_job_dto.dart';
import 'package:career_client_agent/features/opportunities/data/mapper/opportunity_mapper.dart';

abstract final class GovernmentJobMapper {
  static GovernmentJobModel toModel(GovernmentJobDto dto) {
    final item = dto.opportunity;
    return GovernmentJobModel(
      id: item.id,
      title: item.title,
      organization: item.organization,
      location: item.location,
      sourceLink: item.sourceLink,
      postedDate: OpportunityMapper.postedDate(item),
      deadline: OpportunityMapper.deadline(item),
      requiredSkills: item.requiredSkills,
      matchScore: item.matchScore,
      fresherFriendly: item.fresherFriendly,
      visaSponsorship: item.visaSponsorship,
      trainingProvided: item.trainingProvided,
      whyMatch: OpportunityMapper.whyMatch(item),
      cvSuggestions: OpportunityMapper.cvSuggestions(item),
      foundAt: OpportunityMapper.foundAt(item),
      sourceName: item.sourceName,
      freshnessStatus: OpportunityMapper.freshnessStatus(item),
      qualificationRequired: item.qualificationRequired,
      domicileRequired: item.domicileRequired,
      provinceEligibility: item.provinceEligibility,
      eligibilityReason: item.eligibilityReason,
      advertisementNumber: item.advertisementNumber,
      postCount: item.postCount,
      jobScale: item.jobScale,
      forceCategory: item.forceCategory,
    );
  }
}
