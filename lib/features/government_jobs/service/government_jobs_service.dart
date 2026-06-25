import 'package:career_client_agent/core/network/api_client.dart';
import 'package:career_client_agent/core/network/api_endpoints.dart';
import 'package:career_client_agent/features/government_jobs/data/dto/government_job_dto.dart';

class GovernmentJobsService {
  const GovernmentJobsService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<GovernmentJobDto>> fetchGovernmentJobs() async {
    final response = await _apiClient.getList(ApiEndpoints.governmentJobs);
    return response.data
        .map(
          (item) =>
              GovernmentJobDto.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }
}
