import 'package:career_client_agent/features/opportunities/data/dto/opportunity_dto.dart';

class ScholarshipDto {
  const ScholarshipDto({required this.opportunity});

  final OpportunityDto opportunity;

  factory ScholarshipDto.fromJson(Map<String, dynamic> json) {
    return ScholarshipDto(opportunity: OpportunityDto.fromJson(json));
  }
}
