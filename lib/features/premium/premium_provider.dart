import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

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

// ── RevenueCat 설정 ───────────────────────────────────────────────
// App Store Connect에서 발급한 RevenueCat iOS API 키를 여기에 입력하세요
// app.revenuecat.com → 프로젝트 → iOS → API Key (appl_XXXX...)
const _rcApiKey = 'appl_YOUR_REVENUECAT_API_KEY';

// RevenueCat 대시보드 Entitlements 탭에서 만든 entitlement identifier
const _entitlementId = 'pro';

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

  Future<void> _init() async {
    try {
      await Purchases.setLogLevel(LogLevel.warn);
      await Purchases.configure(PurchasesConfiguration(_rcApiKey));

      // 구독 상태 실시간 감지 (앱 포그라운드 복귀, 구매 완료 등)
      Purchases.addCustomerInfoUpdateListener((info) {
        _applyCustomerInfo(info);
      });

      // 초기 구독 상태 로드
      final info = await Purchases.getCustomerInfo();
      _applyCustomerInfo(info);
    } catch (_) {
      // 플러그인 미등록(테스트 환경) 또는 네트워크 실패 시 무료 상태 유지
    }
  }

  void _applyCustomerInfo(CustomerInfo info) {
    final isPro = info.entitlements.active.containsKey(_entitlementId);
    state = state.copyWith(isProUser: isPro, plan: _planFrom(info));
  }

  SubscriptionPlan _planFrom(CustomerInfo info) {
    if (!info.entitlements.active.containsKey(_entitlementId)) {
      return SubscriptionPlan.free;
    }
    final productId =
        info.entitlements.active[_entitlementId]?.productIdentifier ?? '';
    return productId.contains('annual')
        ? SubscriptionPlan.annual
        : SubscriptionPlan.monthly;
  }

  // ── 구매 ────────────────────────────────────────────────────────

  /// Pro 구독 구매 (월간)
  Future<void> purchaseMonthly() => _purchase(PackageType.monthly);

  /// Pro 구독 구매 (연간)
  Future<void> purchaseAnnual() => _purchase(PackageType.annual);

  Future<void> _purchase(PackageType type) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final offerings = await Purchases.getOfferings();
      final pkg = offerings.current?.availablePackages
          .where((p) => p.packageType == type)
          .firstOrNull;

      if (pkg == null) {
        state = state.copyWith(isLoading: false, error: '상품을 찾을 수 없습니다');
        return;
      }

      final info = await Purchases.purchasePackage(pkg);
      _applyCustomerInfo(info);
      state = state.copyWith(isLoading: false);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        // 사용자가 직접 취소 — 에러 메시지 불필요
        state = state.copyWith(isLoading: false);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: _errorMessage(code),
        );
      }
    }
  }

  // ── 복원 ────────────────────────────────────────────────────────

  Future<void> restorePurchases() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final info = await Purchases.restorePurchases();
      _applyCustomerInfo(info);
      final isPro = info.entitlements.active.containsKey(_entitlementId);
      state = state.copyWith(
        isLoading: false,
        error: isPro ? null : '복원할 구독이 없습니다',
      );
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      state = state.copyWith(isLoading: false, error: _errorMessage(code));
    }
  }

  // ── 유틸 ─────────────────────────────────────────────────────────

  String _errorMessage(PurchasesErrorCode code) {
    switch (code) {
      case PurchasesErrorCode.networkError:
        return '네트워크 연결을 확인해주세요';
      case PurchasesErrorCode.productNotAvailableForPurchaseError:
        return '현재 구매할 수 없는 상품입니다';
      case PurchasesErrorCode.purchaseNotAllowedError:
        return '이 기기에서는 구매가 허용되지 않습니다';
      case PurchasesErrorCode.receiptAlreadyInUseError:
        return '이미 다른 계정에서 사용 중인 구독입니다';
      default:
        return '구매에 실패했습니다. 다시 시도해주세요';
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

// ── Provider ─────────────────────────────────────────────────────
final premiumProvider = StateNotifierProvider<PremiumNotifier, PremiumState>(
  (_) => PremiumNotifier(),
);
