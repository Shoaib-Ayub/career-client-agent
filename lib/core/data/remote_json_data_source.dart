import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/network/network_exception.dart';
import 'package:http/http.dart' as http;

class RemoteJsonDataSource {
  RemoteJsonDataSource({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<List<Map<String, dynamic>>> loadList(String path) async {
    final payload = await _load(path);
    if (payload is! List) {
      throw const NetworkException(AppStrings.invalidResponseMessage);
    }
    final records = payload
        .map((item) => Map<String, dynamic>.from(item as Map<dynamic, dynamic>))
        .toList();
    if (records.isEmpty) {
      throw const NetworkException(AppStrings.emptyRemoteDataMessage);
    }
    return records;
  }

  Future<Map<String, dynamic>> loadObject(String path) async {
    final payload = await _load(path);
    if (payload is! Map) {
      throw const NetworkException(AppStrings.invalidResponseMessage);
    }
    return Map<String, dynamic>.from(payload);
  }

  Future<dynamic> _load(String path) async {
    if (baseUrl.trim().isEmpty) {
      throw const NetworkException(AppStrings.remoteDataNotConfigured);
    }
    try {
      final response = await _client
          .get(Uri.parse('${_normalizedBaseUrl()}/$path'))
          .timeout(AppConstants.apiTimeout);
      if (response.statusCode == HttpStatus.notFound) {
        throw const NetworkException(
          AppStrings.remoteFileMissing,
          statusCode: HttpStatus.notFound,
        );
      }
      if (response.statusCode == HttpStatus.tooManyRequests) {
        throw const NetworkException(
          AppStrings.githubRateLimitMessage,
          statusCode: HttpStatus.tooManyRequests,
        );
      }
      if (response.statusCode < AppConstants.successStatusCodeStart ||
          response.statusCode > AppConstants.successStatusCodeEnd) {
        throw NetworkException(
          AppStrings.networkErrorMessage,
          statusCode: response.statusCode,
        );
      }
      return jsonDecode(response.body);
    } on TimeoutException {
      throw const NetworkException(AppStrings.requestTimeoutMessage);
    } on SocketException {
      throw const NetworkException(AppStrings.networkErrorMessage);
    } on FormatException {
      throw const NetworkException(AppStrings.invalidResponseMessage);
    } on TypeError {
      throw const NetworkException(AppStrings.invalidResponseMessage);
    } on NetworkException {
      rethrow;
    } on Exception {
      throw const NetworkException(AppStrings.unknownNetworkError);
    }
  }

  String _normalizedBaseUrl() => baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
}
