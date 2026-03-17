import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:color_pop/features/premium/premium_provider.dart';

void main() {
  // ── PremiumState ───────────────────────────────────────────────
  group('PremiumState', () {
    test('기본값 검증', () {
      const state = PremiumState();
      expect(state.isProUser, isFalse);
      expect(state.plan, SubscriptionPlan.free);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('copyWith: isProUser 변경', () {
      const state = PremiumState();
      final pro = state.copyWith(isProUser: true, plan: SubscriptionPlan.annual);
      expect(pro.isProUser, isTrue);
      expect(pro.plan, SubscriptionPlan.annual);
    });

    test('copyWith: isLoading 변경', () {
      const state = PremiumState();
      final loading = state.copyWith(isLoading: true);
      expect(loading.isLoading, isTrue);
      expect(loading.isProUser, isFalse);
    });

    test('copyWith: error 설정 및 clearError', () {
      const state = PremiumState(error: '구매 실패');
      expect(state.error, '구매 실패');

      final cleared = state.copyWith(clearError: true);
      expect(cleared.error, isNull);
    });

    test('copyWith: 변경하지 않은 필드 유지', () {
      const state = PremiumState(
        isProUser: true,
        plan: SubscriptionPlan.monthly,
      );
      final updated = state.copyWith(isLoading: true);
      expect(updated.isProUser, isTrue);
      expect(updated.plan, SubscriptionPlan.monthly);
    });
  });

  // ── isLocked ───────────────────────────────────────────────────
  group('PremiumState.isLocked', () {
    test('Pro 사용자는 모든 기능이 잠금 해제된다', () {
      const state = PremiumState(isProUser: true);
      for (final feature in PremiumFeature.values) {
        expect(state.isLocked(feature), isFalse,
            reason: '${feature.name}이 Pro에서 잠겨있으면 안 됨');
      }
    });

    test('무료 사용자는 Pro 기능이 잠금된다', () {
      const state = PremiumState(isProUser: false);
      expect(state.isLocked(PremiumFeature.aiSegmentation), isTrue);
      expect(state.isLocked(PremiumFeature.loopVideo), isTrue);
      expect(state.isLocked(PremiumFeature.highResExport), isTrue);
      expect(state.isLocked(PremiumFeature.cameraAiMode), isTrue);
    });
  });

  // ── PremiumFeature ─────────────────────────────────────────────
  group('PremiumFeature', () {
    test('6가지 기능이 정의되어 있다', () {
      expect(PremiumFeature.values.length, 6);
      expect(PremiumFeature.values, containsAll([
        PremiumFeature.aiSegmentation,
        PremiumFeature.allEffects,
        PremiumFeature.loopVideo,
        PremiumFeature.cameraAiMode,
        PremiumFeature.highResExport,
        PremiumFeature.depthAwareSplash,
      ]));
    });
  });

  // ── SubscriptionPlan ───────────────────────────────────────────
  group('SubscriptionPlan', () {
    test('3가지 플랜이 정의되어 있다', () {
      expect(SubscriptionPlan.values.length, 3);
      expect(SubscriptionPlan.values, containsAll([
        SubscriptionPlan.free,
        SubscriptionPlan.monthly,
        SubscriptionPlan.annual,
      ]));
    });

    test('연간 플랜이 월간보다 높은 index를 가진다', () {
      expect(SubscriptionPlan.annual.index,
          greaterThan(SubscriptionPlan.monthly.index));
    });
  });

  // ── PremiumNotifier 초기 상태 ──────────────────────────────────
  group('PremiumNotifier 초기 상태', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test('초기 상태가 free이다', () {
      final notifier = PremiumNotifier();
      // _init()은 비동기이므로 동기 초기 상태만 검증
      expect(notifier.state.isProUser, isFalse);
      expect(notifier.state.plan, SubscriptionPlan.free);
      expect(notifier.state.isLoading, isFalse);
    });
  });

  // ── PremiumState 체이닝 ────────────────────────────────────────
  group('PremiumState 체이닝', () {
    test('구매 완료 시나리오 상태 전이', () {
      const initial = PremiumState();

      // 1. 구매 시작
      final loading = initial.copyWith(isLoading: true);
      expect(loading.isLoading, isTrue);
      expect(loading.isProUser, isFalse);

      // 2. 구매 성공
      final success = loading.copyWith(
        isLoading: false,
        isProUser: true,
        plan: SubscriptionPlan.annual,
      );
      expect(success.isLoading, isFalse);
      expect(success.isProUser, isTrue);
      expect(success.plan, SubscriptionPlan.annual);
    });

    test('구매 실패 시나리오 상태 전이', () {
      const initial = PremiumState();
      final loading = initial.copyWith(isLoading: true);
      final failed = loading.copyWith(
        isLoading: false,
        error: '결제 취소됨',
      );
      expect(failed.isLoading, isFalse);
      expect(failed.isProUser, isFalse);
      expect(failed.error, '결제 취소됨');
    });
  });
}
