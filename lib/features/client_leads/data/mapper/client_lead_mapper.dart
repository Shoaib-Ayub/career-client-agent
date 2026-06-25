import 'package:career_client_agent/core/storage/models/client_lead_model.dart';
import 'package:career_client_agent/features/client_leads/data/dto/client_lead_dto.dart';
import 'package:career_client_agent/features/opportunities/data/mapper/opportunity_mapper.dart';

abstract final class ClientLeadMapper {
  static ClientLeadModel toModel(ClientLeadDto dto) {
    final item = dto.opportunity;
    return ClientLeadModel(
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
      leadCategory: item.leadCategory,
      budget: item.budget,
      budgetType: item.budgetType,
      country: item.country,
      platform: item.platform,
      proposalUrl: item.proposalUrl,
      leadScore: item.leadScore,
      whyGoodLead: item.whyGoodLead,
      suggestedMessage: item.suggestedMessage,
      shortMessage: item.shortMessage,
      manualAction: item.manualAction,
      expectedLeadType: item.expectedLeadType,
      searchKeyword: item.searchKeyword,
      platformProjectId: item.platformProjectId,
    );
  }
}
