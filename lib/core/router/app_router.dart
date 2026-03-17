import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/home/home_screen.dart';
import '../../features/editor/editor_screen.dart';
import '../../features/camera/camera_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../models/edit_item.dart';

/// 첫 실행 온보딩 표시 여부 (앱 기동 시 1회 체크)
final _hasSeenOnboardingProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('hasSeenOnboarding') ?? false;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  // 온보딩 완료 여부 반응형 감지 (FutureProvider 구독)
  final onboardingAsync = ref.watch(_hasSeenOnboardingProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: false,
    redirect: (context, state) {
      // 아직 로딩 중이면 redirect 없음
      if (onboardingAsync.isLoading) return null;
      final hasSeen = onboardingAsync.valueOrNull ?? false;

      // 온보딩 미완료 + 온보딩 화면이 아닌 경우 → 온보딩으로
      if (!hasSeen && state.matchedLocation != '/onboarding') {
        return '/onboarding';
      }
      // 온보딩 완료 상태에서 온보딩 경로 접근 → 홈으로
      if (hasSeen && state.matchedLocation == '/onboarding') {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/editor',
        builder: (context, state) {
          final item = state.extra as EditItem?;
          return EditorScreen(item: item);
        },
      ),
      GoRoute(
        path: '/camera',
        builder: (context, state) => const CameraScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('경로를 찾을 수 없습니다: ${state.uri}'),
      ),
    ),
  );
});
