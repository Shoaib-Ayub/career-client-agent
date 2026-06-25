import 'package:career_client_agent/features/opportunities/data/dto/opportunity_dto.dart';

class JobDto {
  const JobDto({required this.opportunity});

  final OpportunityDto opportunity;

  factory JobDto.fromJson(Map<String, dynamic> json) {
    return JobDto(opportunity: OpportunityDto.fromJson(json));
  }
}
