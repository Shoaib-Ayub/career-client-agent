import 'package:career_client_agent/core/constants/app_icons.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SourceLinkButton extends StatelessWidget {
  const SourceLinkButton({
    required this.sourceLink,
    this.label = AppStrings.viewSource,
    super.key,
  });

  final String sourceLink;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _openSource(context),
      icon: const Icon(AppIcons.sourceLink),
      label: Text(label),
    );
  }

  Future<void> _openSource(BuildContext context) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(sourceLink),
        mode: LaunchMode.externalApplication,
      );
    } on Exception {
      opened = false;
    }

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.sourceLinkUnavailable)),
      );
    }
  }
}
