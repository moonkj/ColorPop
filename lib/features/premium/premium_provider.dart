import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── 프리미엄 기능 목록 ────────────────────────────────────────────
enum PremiumFeature {
  aiSegmentation,   // AI 세그멘테이션 (무제한)
  allEffects,       // 모든 바이럴 이펙트
  loopVideo,        // Loop 영상 생성
  cameraAiMode,     // 카메라 AI 모드
  highResExport,    // 원본 해상도 내보내기
  depthAwareSplash, // Depth-Aware Splash (LiDAR)
}

// ── 구독 플랜 ────────────────────────────────────────────────────
enum SubscriptionPlan {
  free,
  monthly,  // $3.99/월
  annual,   // $29.99/년
}

// ── 상태 ─────────────────────────────────────────────────────────
class PremiumState {
  final bool isProUser;
  final SubscriptionPlan plan;
  final bool isLoading;
  final String? error;

  const PremiumState({
    this.isProUser = false,
    this.plan = SubscriptionPlan.free,
    this.isLoading = false,
    this.error,
  });

  /// 특정 기능이 잠겨 있는지 (Pro 전용 기능이고 미구독인 경우)
  bool isLocked(PremiumFeature feature) {
    if (isProUser) return false;
    // 무료 티어에서도 사용 가능한 기능
    const freeFeatures = <PremiumFeature>{};
    return !freeFeatures.contains(feature);
  }

  PremiumState copyWith({
    bool? isProUser,
    SubscriptionPlan? plan,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return PremiumState(
      isProUser: isProUser ?? this.isProUser,
      plan: plan ?? this.plan,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────
class PremiumNotifier extends StateNotifier<PremiumState> {
  PremiumNotifier() : super(const PremiumState()) {
    _init();
  }

  static const _keyIsProUser = 'is_pro_user';
  static const _keyPlan = 'subscription_plan';

  Future<void> _init() async {
    // TODO: RevenueCat 초기화
    // await Purchases.configure(PurchasesConfiguration('YOUR_REVENUECAT_API_KEY'));

    final prefs = await SharedPreferences.getInstance();
    final isPro  = prefs.getBool(_keyIsProUser) ?? false;
    final planIdx = prefs.getInt(_keyPlan) ?? 0;
    state = state.copyWith(
      isProUser: isPro,
      plan: SubscriptionPlan.values[planIdx.clamp(0, SubscriptionPlan.values.length - 1)],
    );
  }

  /// Pro 구독 구매 (월간)
  Future<void> purchaseMonthly() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // TODO: RevenueCat 구매
      // final offerings = await Purchases.getOfferings();
      // final package = offerings.current?.monthly;
      // if (package != null) {
      //   await Purchases.purchasePackage(package);
      // }

      // Mock: 구매 성공 시뮬레이션 (개발/테스트용)
      await _setPro(true, SubscriptionPlan.monthly);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '구매에 실패했습니다: $e');
    }
  }

  /// Pro 구독 구매 (연간)
  Future<void> purchaseAnnual() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // TODO: RevenueCat 연간 구독 구매
      await _setPro(true, SubscriptionPlan.annual);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '구매에 실패했습니다: $e');
    }
  }

  /// 구독 복원
  Future<void> restorePurchases() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // TODO: RevenueCat 복원
      // final customerInfo = await Purchases.restorePurchases();
      // final isPro = customerInfo.entitlements.active.containsKey('pro');

      final prefs = await SharedPreferences.getInstance();
      final isPro = prefs.getBool(_keyIsProUser) ?? false;
      state = state.copyWith(
        isLoading: false,
        isProUser: isPro,
        error: isPro ? null : '복원할 구독이 없습니다',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '복원에 실패했습니다: $e');
    }
  }

  Future<void> _setPro(bool isPro, SubscriptionPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsProUser, isPro);
    await prefs.setInt(_keyPlan, plan.index);
    state = state.copyWith(isProUser: isPro, plan: plan, isLoading: false);
  }

  void clearError() => state = state.copyWith(clearError: true);
}

// ── Provider ─────────────────────────────────────────────────────
final premiumProvider = StateNotifierProvider<PremiumNotifier, PremiumState>(
  (_) => PremiumNotifier(),
);
