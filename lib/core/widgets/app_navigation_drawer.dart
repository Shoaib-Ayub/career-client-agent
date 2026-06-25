import 'package:career_client_agent/app/view_model/app_navigation_view_model.dart';
import 'package:career_client_agent/core/constants/app_colors.dart';
import 'package:career_client_agent/core/constants/app_icons.dart';
import 'package:career_client_agent/core/constants/app_sizes.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:flutter/material.dart';

class AppNavigationDrawer extends StatelessWidget {
  const AppNavigationDrawer({
    required this.destinations,
    required this.selectedPageIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final List<AppNavigationDestination> destinations;
  final int selectedPageIndex;
  final ValueChanged<AppNavigationDestination> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSizes.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    AppIcons.app,
                    size: AppSizes.drawerHeaderIconSize,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: AppSizes.spaceMd),
                  Text(
                    AppStrings.appName,
                    style: textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSizes.spaceXs),
                  Text(
                    AppStrings.navigationMenu,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(
              color: AppColors.border,
              height: AppSizes.borderWidth,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.spaceLg,
                AppSizes.spaceLg,
                AppSizes.spaceLg,
                AppSizes.spaceXs,
              ),
              child: Text(
                AppStrings.accountSections,
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ...destinations.map((destination) {
              final isSelected = selectedPageIndex == destination.pageIndex;

              return ListTile(
                selected: isSelected,
                selectedColor: AppColors.navigationSelected,
                selectedTileColor: AppColors.navigationIndicator,
                leading: Icon(destination.icon),
                title: Text(destination.label),
                onTap: () => onDestinationSelected(destination),
              );
            }),
          ],
        ),
      ),
    );
  }
}
