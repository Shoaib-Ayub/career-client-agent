import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:flutter/material.dart';

abstract final class RefreshFeedback {
  static Future<void> show(
    BuildContext context,
    Future<bool> Function() refresh,
  ) async {
    final succeeded = await refresh();
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            succeeded
                ? AppStrings.refreshedSuccessfully
                : AppStrings.networkErrorMessage,
          ),
        ),
      );
  }
}
