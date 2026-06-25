import 'package:career_client_agent/core/storage/models/scholarship_model.dart';
import 'package:career_client_agent/features/opportunities/data/mapper/opportunity_mapper.dart';
import 'package:career_client_agent/features/scholarships/data/dto/scholarship_dto.dart';

abstract final class ScholarshipMapper {
  static ScholarshipModel toModel(ScholarshipDto dto) {
    final item = dto.opportunity;
    return ScholarshipModel(
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
    );
  }
}
