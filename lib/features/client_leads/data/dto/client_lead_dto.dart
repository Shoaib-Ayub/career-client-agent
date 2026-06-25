import 'package:career_client_agent/features/opportunities/data/dto/opportunity_dto.dart';

class ClientLeadDto {
  const ClientLeadDto({required this.opportunity});

  final OpportunityDto opportunity;

  factory ClientLeadDto.fromJson(Map<String, dynamic> json) {
    return ClientLeadDto(opportunity: OpportunityDto.fromJson(json));
  }
}
