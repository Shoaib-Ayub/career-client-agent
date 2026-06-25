import 'package:career_client_agent/features/opportunities/data/dto/opportunity_dto.dart';

class GovernmentJobDto {
  const GovernmentJobDto({required this.opportunity});

  final OpportunityDto opportunity;

  factory GovernmentJobDto.fromJson(Map<String, dynamic> json) {
    return GovernmentJobDto(opportunity: OpportunityDto.fromJson(json));
  }
}
