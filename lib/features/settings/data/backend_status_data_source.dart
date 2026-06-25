import 'dart:convert';

import 'package:career_client_agent/core/constants/app_constants.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/data/remote_json_data_source.dart';
import 'package:career_client_agent/core/network/network_exception.dart';
import 'package:career_client_agent/core/network/remote_json_endpoints.dart';
import 'package:career_client_agent/features/settings/model/backend_run_status.dart';
import 'package:flutter/services.dart';

class BackendStatusDataSource {
  BackendStatusDataSource({
    AssetBundle? assetBundle,
    RemoteJsonDataSource? remote,
  }) : _assetBundle = assetBundle ?? rootBundle,
       _remote = remote;

  final AssetBundle _assetBundle;
  final RemoteJsonDataSource? _remote;

  Future<BackendRunStatus> loadRemote() async {
    final remote = _remote;
    if (remote == null) {
      throw const NetworkException(AppStrings.remoteDataNotConfigured);
    }
    return _fromJson(await remote.loadObject(RemoteJsonEndpoints.runStatus));
  }

  Future<BackendRunStatus> load() async {
    final remote = _remote;
    if (remote != null) {
      try {
        return await loadRemote();
      } on Exception {
        // The bundled status remains available when remote status fails.
      }
    }
    final source = await _assetBundle.loadString(
      AppConstants.backendRunStatusAsset,
      cache: false,
    );
    final payload = Map<String, dynamic>.from(
      jsonDecode(source) as Map<dynamic, dynamic>,
    );
    return _fromJson(payload);
  }

  BackendRunStatus _fromJson(Map<String, dynamic> payload) {
    return BackendRunStatus(
      lastRunTime: DateTime.tryParse(
        (payload['last_run_time'] ?? '').toString(),
      ),
      totalJobs: (payload['total_jobs'] ?? 0) as int,
      totalScholarships: (payload['total_scholarships'] ?? 0) as int,
      totalGovernmentJobs: (payload['total_government_jobs'] ?? 0) as int,
      totalClientLeads: (payload['total_client_leads'] ?? 0) as int,
      failedSources: List<String>.from(
        payload['failed_sources'] as List? ?? const [],
      ),
    );
  }
}
