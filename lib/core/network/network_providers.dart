import 'package:career_client_agent/core/config/app_config.dart';
import 'package:career_client_agent/core/network/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(baseUrl: AppConfig.apiBaseUrl);
});
