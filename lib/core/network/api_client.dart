import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/network/api_response.dart';
import 'package:career_client_agent/core/network/network_exception.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<ApiResponse<List<dynamic>>> getList(String endpoint) async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl$endpoint'))
          .timeout(AppConstants.apiTimeout);

      if (response.statusCode < AppConstants.successStatusCodeStart ||
          response.statusCode > AppConstants.successStatusCodeEnd) {
        throw NetworkException(
          AppStrings.networkErrorMessage,
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(response.body);
      final data = decoded is Map<String, dynamic> ? decoded['data'] : decoded;
      if (data is! List) {
        throw const NetworkException(AppStrings.invalidResponseMessage);
      }

      return ApiResponse(
        data: List<dynamic>.from(data),
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      throw const NetworkException(AppStrings.requestTimeoutMessage);
    } on SocketException {
      throw const NetworkException(AppStrings.networkErrorMessage);
    } on FormatException {
      throw const NetworkException(AppStrings.invalidResponseMessage);
    } on NetworkException {
      rethrow;
    } on Exception {
      throw const NetworkException(AppStrings.unknownNetworkError);
    }
  }
}
