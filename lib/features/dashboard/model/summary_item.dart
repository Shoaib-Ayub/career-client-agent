import 'package:flutter/material.dart';

@immutable
class SummaryItem {
  const SummaryItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
}
