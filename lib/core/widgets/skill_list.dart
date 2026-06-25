import 'package:career_client_agent/core/constants/app_sizes.dart';
import 'package:career_client_agent/core/widgets/skill_chip.dart';
import 'package:flutter/material.dart';

class SkillList extends StatelessWidget {
  const SkillList({required this.skills, super.key});

  final List<String> skills;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSizes.spaceXs,
      runSpacing: AppSizes.spaceXs,
      children: skills.map((skill) => SkillChip(label: skill)).toList(),
    );
  }
}
