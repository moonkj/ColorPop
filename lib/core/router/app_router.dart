import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/home/home_screen.dart';
import '../../features/editor/editor_screen.dart';
import '../../features/camera/camera_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../models/edit_item.dart';

/// 온보딩 완료 여부 상태 — ChangeNotifier를 통해 GoRouter redirect를 트리거
class OnboardingStatus extends ChangeNotifier {
  bool _loaded = false;
  bool _hasSeen = false;

  bool get loaded => _loaded;
  bool get hasSeen => _hasSeen;

  /// 온보딩 완료 시 즉시 메모리 상태 갱신 — GoRouter redirect 재평가 트리거
  void markAsSeen() {
    _hasSeen = true;
    notifyListeners();
  }

  /// runApp() 이후에 호출 — 플러그인이 준비된 시점에서 SharedPreferences 로드
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasSeen = prefs.getBool('hasSeenOnboarding') ?? false;
    } catch (_) {
      _hasSeen = false;
    }
    _loaded = true;
    notifyListeners(); // GoRouter redirect 재실행
  }
}

/// 전역 싱글턴 — main()에서 load() 호출
final onboardingStatus = OnboardingStatus();

/// GoRouter 인스턴스 — 단 한 번만 생성, refreshListenable로 redirect 재실행
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: onboardingStatus, // 상태 변경 시 redirect 재실행
    debugLogDiagnostics: false,
    redirect: (context, state) {
      // 아직 로딩 중 → 스플래시 유지 (이미 /splash면 null 반환으로 루프 방지)
      if (!onboardingStatus.loaded) {
        return state.matchedLocation == '/splash' ? null : '/splash';
      }

      final hasSeen = onboardingStatus.hasSeen;

      if (state.matchedLocation == '/splash') {
        return hasSeen ? '/' : '/onboarding';
      }
      if (!hasSeen && state.matchedLocation != '/onboarding') {
        return '/onboarding';
      }
      if (hasSeen && state.matchedLocation == '/onboarding') {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const _SplashScreen(),
      ),
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
      body: Center(child: Text('경로를 찾을 수 없습니다: ${state.uri}')),
    ),
  );

  ref.onDispose(router.dispose);
  return router;
});

/// 앱 시작 시 잠깐 표시되는 스플래시
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A0A0F),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF7B5CFA)),
      ),
    );
  }
}
