import 'package:career_client_agent/app/routes/app_routes.dart';
import 'package:career_client_agent/core/constants/app_colors.dart';
import 'package:career_client_agent/core/constants/app_assets.dart';
import 'package:career_client_agent/core/constants/app_sizes.dart';
import 'package:career_client_agent/core/constants/app_strings.dart';
import 'package:career_client_agent/features/splash/view_model/splash_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _openDashboard();
  }

  Future<void> _openDashboard() async {
    await ref.read(splashViewModelProvider).initialize();

    if (mounted) {
      context.goNamed(AppRoutes.dashboardName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.brandNavy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spaceLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: AppSizes.spaceMd),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppSizes.splashLogoMaxWidth,
                      maxHeight: AppSizes.splashLogoMaxHeight,
                    ),
                    child: Image.asset(
                      AppAssets.appLogo,
                      fit: BoxFit.contain,
                      semanticLabel: AppStrings.appName,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.spaceMd),
              Text(
                AppStrings.appName,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.spaceSm),
              Text(
                AppStrings.brandSubtitle,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.electricBlue,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              const SizedBox.square(
                dimension: AppSizes.splashProgressSize,
                child: CircularProgressIndicator(
                  strokeWidth: AppSizes.splashProgressStrokeWidth,
                ),
              ),
              const SizedBox(height: AppSizes.spaceMd),
              Text(
                AppStrings.loading,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
