import 'package:career_client_agent/core/network/api_client.dart';
import 'package:career_client_agent/core/network/api_endpoints.dart';
import 'package:career_client_agent/features/jobs/data/dto/job_dto.dart';

class JobsService {
  const JobsService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<JobDto>> fetchJobs() async {
    final response = await _apiClient.getList(ApiEndpoints.jobs);
    return response.data
        .map((item) => JobDto.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }
}
