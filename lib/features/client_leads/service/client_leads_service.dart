import 'package:career_client_agent/core/network/api_client.dart';
import 'package:career_client_agent/core/network/api_endpoints.dart';
import 'package:career_client_agent/features/client_leads/data/dto/client_lead_dto.dart';

class ClientLeadsService {
  const ClientLeadsService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ClientLeadDto>> fetchClientLeads() async {
    final response = await _apiClient.getList(ApiEndpoints.clientLeads);
    return response.data
        .map(
          (item) =>
              ClientLeadDto.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }
}
