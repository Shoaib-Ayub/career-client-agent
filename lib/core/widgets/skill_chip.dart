import 'package:career_client_agent/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class SkillChip extends StatelessWidget {
  const SkillChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: AppColors.navigationIndicator,
      side: const BorderSide(color: AppColors.border),
      labelStyle: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(color: AppColors.navigationSelected),
    );
  }
}
