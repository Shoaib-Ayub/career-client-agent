import 'package:flutter/material.dart';

@immutable
class PageContent {
  const PageContent({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}
