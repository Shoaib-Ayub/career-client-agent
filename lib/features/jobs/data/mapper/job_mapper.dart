import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/storage/models/job_model.dart';
import 'package:career_client_agent/features/jobs/data/dto/job_dto.dart';
import 'package:career_client_agent/features/opportunities/data/mapper/opportunity_mapper.dart';

abstract final class JobMapper {
  static JobModel toModel(JobDto dto) {
    final item = dto.opportunity;
    return JobModel(
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
      requiredEducation: AppStrings.mockJobEducation,
      minimumExperienceYears: AppConstants.defaultExperienceYears,
      jobType: AppStrings.mockJobType,
      foundAt: OpportunityMapper.foundAt(item),
      sourceName: item.sourceName,
      freshnessStatus: OpportunityMapper.freshnessStatus(item),
    );
  }
}
