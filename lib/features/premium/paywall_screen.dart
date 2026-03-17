import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../services/haptic_service.dart';
import '../../services/sound_service.dart';
import 'premium_provider.dart';

/// Pro 업그레이드 Paywall 화면
class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(premiumProvider);

    ref.listen<PremiumState>(premiumProvider, (prev, next) {
      if (next.isProUser && !(prev?.isProUser ?? false)) {
        HapticService.success();
        SoundService.saveSuccess();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(AppStrings.paywallSuccessMessage),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
          ),
        );
      }
      if (next.error != null && prev?.error != next.error) {
        HapticService.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
          ),
        );
        ref.read(premiumProvider.notifier).clearError();
      }
    });

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusXl)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              children: [
                _Handle(),
                _HeroSection(),
                const SizedBox(height: AppSizes.lg),
                _FeatureList(),
                const SizedBox(height: AppSizes.lg),
                _PricingSection(state: state),
                const SizedBox(height: AppSizes.md),
                _RestoreButton(state: state),
                const SizedBox(height: AppSizes.sm),
                _LegalText(),
                const SizedBox(height: AppSizes.xl),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── 핸들 ─────────────────────────────────────────────────────────
class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      child: Container(
        width: 40, height: 4,
        decoration: BoxDecoration(
          color: AppColors.textTertiary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ── 히어로 섹션 ───────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSizes.md, AppSizes.sm, AppSizes.md, AppSizes.md),
      child: Column(
        children: [
          // 아이콘
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppSizes.radiusXl),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: AppSizes.iconXl,
            ),
          ),
          const SizedBox(height: AppSizes.md),
          ShaderMask(
            shaderCallback: (bounds) =>
                AppColors.primaryGradient.createShader(bounds),
            child: const Text(
              AppStrings.paywallTitle,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          const Text(
            AppStrings.paywallSubtitle,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── 기능 목록 ─────────────────────────────────────────────────────
class _FeatureList extends StatelessWidget {
  static const _features = [
    (Icons.auto_awesome_outlined, AppStrings.paywallFeatureAi),
    (Icons.blur_on_outlined,      AppStrings.paywallFeatureEffects),
    (Icons.videocam_outlined,     AppStrings.paywallFeatureLoop),
    (Icons.camera_alt_outlined,   AppStrings.paywallFeatureCamera),
    (Icons.photo_size_select_large_outlined, AppStrings.paywallFeatureHighRes),
    (Icons.layers_outlined,       AppStrings.paywallFeatureDepth),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Column(
        children: _features.asMap().entries.map((entry) {
          final isLast = entry.key == _features.length - 1;
          final (icon, label) = entry.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.md, vertical: AppSizes.sm),
                child: Row(
                  children: [
                    Icon(icon, color: AppColors.primaryLight, size: 20),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Icon(Icons.check_circle,
                        color: AppColors.success, size: 18),
                  ],
                ),
              ),
              if (!isLast)
                const Divider(
                    color: AppColors.divider, height: 1, indent: 44),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── 요금제 섹션 ───────────────────────────────────────────────────
class _PricingSection extends ConsumerWidget {
  final PremiumState state;
  const _PricingSection({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isProUser) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.md),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified, color: AppColors.success),
              SizedBox(width: AppSizes.sm),
              Text(
                AppStrings.paywallAlreadyPro,
                style: TextStyle(
                    color: AppColors.success, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      child: Column(
        children: [
          // 연간 구독 (추천)
          _PlanCard(
            label: AppStrings.paywallAnnualLabel,
            price: AppStrings.paywallAnnualPrice,
            badge: AppStrings.paywallBestValue,
            isRecommended: true,
            isLoading: state.isLoading,
            onTap: () {
              HapticService.medium();
              ref.read(premiumProvider.notifier).purchaseAnnual();
            },
          ),
          const SizedBox(height: AppSizes.sm),
          // 월간 구독
          _PlanCard(
            label: AppStrings.paywallMonthlyLabel,
            price: AppStrings.paywallMonthlyPrice,
            isRecommended: false,
            isLoading: state.isLoading,
            onTap: () {
              HapticService.light();
              ref.read(premiumProvider.notifier).purchaseMonthly();
            },
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String label;
  final String price;
  final String? badge;
  final bool isRecommended;
  final bool isLoading;
  final VoidCallback onTap;

  const _PlanCard({
    required this.label,
    required this.price,
    this.badge,
    required this.isRecommended,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: AppSizes.actionButtonHeight,
        decoration: BoxDecoration(
          gradient: isRecommended ? AppColors.primaryGradient : null,
          color: isRecommended ? null : AppColors.card,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: isRecommended
              ? null
              : Border.all(color: AppColors.divider),
        ),
        child: Stack(
          children: [
            // 가격/레이블 텍스트
            Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: isRecommended
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Text(
                          price,
                          style: TextStyle(
                            color: isRecommended
                                ? Colors.white70
                                : AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
            ),
            // 뱃지
            if (badge != null)
              Positioned(
                right: AppSizes.sm,
                top: AppSizes.sm,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── 복원 버튼 ─────────────────────────────────────────────────────
class _RestoreButton extends ConsumerWidget {
  final PremiumState state;
  const _RestoreButton({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: state.isLoading
          ? null
          : () {
              HapticService.light();
              ref.read(premiumProvider.notifier).restorePurchases();
            },
      child: const Text(
        AppStrings.paywallRestore,
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
    );
  }
}

// ── 법적 텍스트 ───────────────────────────────────────────────────
class _LegalText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.xl),
      child: Text(
        AppStrings.paywallLegal,
        style: TextStyle(
          color: AppColors.textTertiary,
          fontSize: 10,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
