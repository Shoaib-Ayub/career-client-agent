import 'package:career_client_agent/app/view_model/app_navigation_view_model.dart';
import 'package:career_client_agent/core/constants/app_colors.dart';
import 'package:career_client_agent/core/constants/app_sizes.dart';
import 'package:flutter/material.dart';

class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final List<AppNavigationDestination> destinations;
  final int? selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.navigationBackground,
      child: SafeArea(
        top: false,
        child: Container(
          height: AppSizes.bottomNavigationHeight,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(
                color: AppColors.border,
                width: AppSizes.borderWidth,
              ),
            ),
          ),
          child: Row(
            children: List.generate(destinations.length, (index) {
              final destination = destinations[index];
              final isSelected = selectedIndex == index;

              return Expanded(
                child: InkWell(
                  onTap: () => onDestinationSelected(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: AppSizes.bottomNavigationIndicatorSize,
                        height: AppSizes.bottomNavigationIndicatorSize,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.navigationIndicator
                              : AppColors.navigationBackground,
                          borderRadius: BorderRadius.circular(
                            AppSizes.badgeRadius,
                          ),
                        ),
                        child: Icon(
                          destination.icon,
                          size: AppSizes.bottomNavigationIconSize,
                          color: isSelected
                              ? AppColors.navigationSelected
                              : AppColors.navigationUnselected,
                        ),
                      ),
                      Text(
                        destination.label,
                        maxLines: AppSizes.bottomNavigationLabelMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isSelected
                              ? AppColors.navigationSelected
                              : AppColors.navigationUnselected,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
