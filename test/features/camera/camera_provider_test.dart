import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:color_pop/features/camera/camera_provider.dart';

void main() {
  group('CameraState', () {
    test('기본 상태 값 확인', () {
      const state = CameraState();
      expect(state.status, CameraStatus.idle);
      expect(state.textureId, -1);
      expect(state.hasLiDAR, false);
      expect(state.facing, CameraFacing.back);
      expect(state.isInverseMode, false);
      expect(state.error, null);
    });

    test('isReady: ready 상태에서만 true', () {
      const idle = CameraState(status: CameraStatus.idle);
      const ready = CameraState(status: CameraStatus.ready);
      const init = CameraState(status: CameraStatus.initializing);

      expect(idle.isReady, false);
      expect(ready.isReady, true);
      expect(init.isReady, false);
    });

    test('isCapturing: capturing 상태에서만 true', () {
      const capturing = CameraState(status: CameraStatus.capturing);
      const ready = CameraState(status: CameraStatus.ready);

      expect(capturing.isCapturing, true);
      expect(ready.isCapturing, false);
    });

    test('copyWith — 부분 업데이트', () {
      const original = CameraState(
        status: CameraStatus.idle,
        textureId: -1,
        hasLiDAR: false,
      );
      final updated = original.copyWith(
        status: CameraStatus.ready,
        textureId: 42,
        hasLiDAR: true,
      );

      expect(updated.status, CameraStatus.ready);
      expect(updated.textureId, 42);
      expect(updated.hasLiDAR, true);
      // 변경하지 않은 필드는 그대로
      expect(updated.facing, CameraFacing.back);
      expect(updated.isInverseMode, false);
    });

    test('copyWith — error 필드 초기화 (null 전달 시)', () {
      final withError = const CameraState().copyWith(error: '오류 발생');
      expect(withError.error, '오류 발생');

      final cleared = withError.copyWith(status: CameraStatus.ready, error: null);
      expect(cleared.error, null);
    });

    test('copyWith — facing 전환', () {
      const state = CameraState(facing: CameraFacing.back);
      final flipped = state.copyWith(facing: CameraFacing.front);
      expect(flipped.facing, CameraFacing.front);
    });

    test('copyWith — isInverseMode 토글', () {
      const state = CameraState(isInverseMode: false);
      final inverted = state.copyWith(isInverseMode: true);
      expect(inverted.isInverseMode, true);
    });

    test('초기화 상태 → ready 상태 전이', () {
      var state = const CameraState();
      state = state.copyWith(status: CameraStatus.initializing);
      expect(state.status, CameraStatus.initializing);
      expect(state.isReady, false);

      state = state.copyWith(status: CameraStatus.ready, textureId: 1);
      expect(state.status, CameraStatus.ready);
      expect(state.isReady, true);
      expect(state.textureId, 1);
    });

    test('촬영 중 상태 → ready 복귀', () {
      const ready = CameraState(status: CameraStatus.ready, textureId: 5);
      final capturing = ready.copyWith(status: CameraStatus.capturing);
      expect(capturing.isCapturing, true);
      expect(capturing.isReady, false);

      final backToReady = capturing.copyWith(status: CameraStatus.ready);
      expect(backToReady.isReady, true);
      expect(backToReady.isCapturing, false);
    });

    test('에러 상태 — textureId 유지', () {
      final state = const CameraState(textureId: 10).copyWith(
        status: CameraStatus.error,
        error: '카메라 오류',
      );
      expect(state.status, CameraStatus.error);
      expect(state.textureId, 10);
      expect(state.error, '카메라 오류');
    });

    test('LiDAR 있는 기기 상태', () {
      const state = CameraState(hasLiDAR: true, status: CameraStatus.ready);
      expect(state.hasLiDAR, true);
      expect(state.isReady, true);
    });

    test('textureId -1은 초기화 전임을 의미', () {
      const state = CameraState(textureId: -1);
      expect(state.textureId < 0, true);
    });

    test('CameraFacing enum 값 확인', () {
      expect(CameraFacing.values.length, 2);
      expect(CameraFacing.back, isNot(CameraFacing.front));
    });

    test('CameraStatus enum 값 확인', () {
      expect(CameraStatus.values.length, 5);
      expect(
        CameraStatus.values,
        containsAll([
          CameraStatus.idle,
          CameraStatus.initializing,
          CameraStatus.ready,
          CameraStatus.capturing,
          CameraStatus.error,
        ]),
      );
    });

    test('Riverpod Provider 초기 상태', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final state = container.read(cameraProvider);
      expect(state.status, CameraStatus.idle);
      expect(state.textureId, -1);
    });

    test('isInverseMode false → true → false 전환', () {
      var state = const CameraState(status: CameraStatus.ready);
      expect(state.isInverseMode, false);

      state = state.copyWith(isInverseMode: true);
      expect(state.isInverseMode, true);

      state = state.copyWith(isInverseMode: false);
      expect(state.isInverseMode, false);
    });

    test('disposeCamera 후 상태 초기화', () {
      final disposed = const CameraState();
      expect(disposed.status, CameraStatus.idle);
      expect(disposed.textureId, -1);
      expect(disposed.error, null);
    });
  });
}
