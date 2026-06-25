import 'package:career_client_agent/core/network/api_client.dart';
import 'package:career_client_agent/core/network/api_endpoints.dart';
import 'package:career_client_agent/features/scholarships/data/dto/scholarship_dto.dart';

class ScholarshipsService {
  const ScholarshipsService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ScholarshipDto>> fetchScholarships() async {
    final response = await _apiClient.getList(ApiEndpoints.scholarships);
    return response.data
        .map(
          (item) =>
              ScholarshipDto.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }
}
