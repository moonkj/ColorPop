import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../services/haptic_service.dart';

/// 첫 실행 3단계 온보딩 화면
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPage(
      icon: Icons.photo_library_outlined,
      gradient: AppColors.primaryGradient,
      title: AppStrings.onboarding1Title,
      subtitle: AppStrings.onboarding1Subtitle,
    ),
    _OnboardingPage(
      icon: Icons.auto_awesome_outlined,
      gradient: LinearGradient(
        colors: [AppColors.accentSecondary, AppColors.primary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      title: AppStrings.onboarding2Title,
      subtitle: AppStrings.onboarding2Subtitle,
    ),
    _OnboardingPage(
      icon: Icons.share_outlined,
      gradient: LinearGradient(
        colors: [AppColors.accent, AppColors.primary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      title: AppStrings.onboarding3Title,
      subtitle: AppStrings.onboarding3Subtitle,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    HapticService.success();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    if (mounted) context.go('/');
  }

  void _nextPage() {
    HapticService.light();
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 스킵 버튼
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.md),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text(
                    AppStrings.onboardingSkip,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                ),
              ),
            ),

            // 페이지 뷰
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  HapticService.selection();
                  setState(() => _currentPage = index);
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) =>
                    _PageContent(page: _pages[index]),
              ),
            ),

            // 하단: 페이지 인디케이터 + 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSizes.md, AppSizes.md, AppSizes.md, AppSizes.lg),
              child: Column(
                children: [
                  // 점 인디케이터
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: _currentPage == index
                              ? AppColors.primaryGradient
                              : null,
                          color: _currentPage == index
                              ? null
                              : AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.lg),

                  // 다음/시작 버튼
                  GestureDetector(
                    onTap: _nextPage,
                    child: Container(
                      width: double.infinity,
                      height: AppSizes.actionButtonHeight,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius:
                            BorderRadius.circular(AppSizes.actionButtonRadius),
                      ),
                      child: Center(
                        child: Text(
                          _currentPage < _pages.length - 1
                              ? AppStrings.onboardingNext
                              : AppStrings.onboardingStart,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 페이지 데이터 ─────────────────────────────────────────────────
class _OnboardingPage {
  final IconData icon;
  final Gradient gradient;
  final String title;
  final String subtitle;

  const _OnboardingPage({
    required this.icon,
    required this.gradient,
    required this.title,
    required this.subtitle,
  });
}

// ── 페이지 콘텐츠 ─────────────────────────────────────────────────
class _PageContent extends StatelessWidget {
  final _OnboardingPage page;

  const _PageContent({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 아이콘
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              gradient: page.gradient,
              borderRadius: BorderRadius.circular(AppSizes.radiusXl * 2),
            ),
            child: Icon(
              page.icon,
              color: Colors.white,
              size: AppSizes.iconXl * 1.2,
            ),
          ),
          const SizedBox(height: AppSizes.xl),

          // 타이틀
          Text(
            page.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSizes.md),

          // 서브타이틀
          Text(
            page.subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
