import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:flutter/material.dart';

class RetryButton extends StatelessWidget {
  const RetryButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      child: const Text(AppStrings.retry),
    );
  }
}
