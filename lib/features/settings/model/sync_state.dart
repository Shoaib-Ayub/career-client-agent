import 'package:career_client_agent/features/settings/model/backend_run_status.dart';

class SyncState {
  const SyncState({
    required this.status,
    this.isSyncing = false,
    this.errorMessage,
  });

  final BackendRunStatus status;
  final bool isSyncing;
  final String? errorMessage;

  SyncState copyWith({
    BackendRunStatus? status,
    bool? isSyncing,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SyncState(
      status: status ?? this.status,
      isSyncing: isSyncing ?? this.isSyncing,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
