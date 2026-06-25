import 'package:career_client_agent/app/view_model/app_navigation_view_model.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/core/widgets/app_bottom_nav_bar.dart';
import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.title,
    required this.body,
    this.destinations,
    this.selectedIndex,
    this.onDestinationSelected,
    this.drawer,
    super.key,
  });

  final String title;
  final Widget body;
  final List<AppNavigationDestination>? destinations;
  final int? selectedIndex;
  final ValueChanged<int>? onDestinationSelected;
  final Widget? drawer;

  @override
  Widget build(BuildContext context) {
    final navigationDestinations = destinations;
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: canPop
            ? BackButton(onPressed: () => Navigator.of(context).maybePop())
            : null,
        title: Text(title),
        actions: drawer != null && canPop
            ? [
                Builder(
                  builder: (context) => IconButton(
                    tooltip: AppStrings.openNavigationMenu,
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    icon: const Icon(Icons.menu),
                  ),
                ),
              ]
            : null,
      ),
      drawer: drawer,
      body: SafeArea(child: body),
      bottomNavigationBar:
          navigationDestinations == null || onDestinationSelected == null
          ? null
          : AppBottomNavBar(
              destinations: navigationDestinations,
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected!,
            ),
    );
  }
}
