import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:color_pop/features/export/export_provider.dart';

void main() {
  // ── ExportState ────────────────────────────────────────────────
  group('ExportState', () {
    test('기본값 검증', () {
      const state = ExportState();
      expect(state.status, ExportStatus.idle);
      expect(state.activeAction, ExportAction.none);
      expect(state.previewFrame, isNull);
      expect(state.error, isNull);
      expect(state.successMessage, isNull);
      expect(state.isLoading, isFalse);
    });

    test('isLoading: loading 상태일 때만 true', () {
      expect(
        const ExportState(status: ExportStatus.loading).isLoading,
        isTrue,
      );
      expect(
        const ExportState(status: ExportStatus.idle).isLoading,
        isFalse,
      );
      expect(
        const ExportState(status: ExportStatus.success).isLoading,
        isFalse,
      );
      expect(
        const ExportState(status: ExportStatus.error).isLoading,
        isFalse,
      );
    });

    test('copyWith: status 변경', () {
      const state = ExportState();
      final updated = state.copyWith(status: ExportStatus.loading);
      expect(updated.status, ExportStatus.loading);
      expect(updated.activeAction, ExportAction.none);
    });

    test('copyWith: activeAction 변경', () {
      const state = ExportState();
      final updated = state.copyWith(activeAction: ExportAction.savePhoto);
      expect(updated.activeAction, ExportAction.savePhoto);
      expect(updated.status, ExportStatus.idle);
    });

    test('copyWith: error 설정 및 clearError', () {
      const state = ExportState(error: '기존 에러');
      final withError = state.copyWith(error: '새 에러');
      expect(withError.error, '새 에러');

      final cleared = withError.copyWith(clearError: true);
      expect(cleared.error, isNull);
    });

    test('copyWith: successMessage 설정 및 clearSuccess', () {
      const state = ExportState(successMessage: '저장 완료');
      final cleared = state.copyWith(clearSuccess: true);
      expect(cleared.successMessage, isNull);
    });

    test('copyWith: previewFrame 설정 및 clearPreview', () {
      final frame = Uint8List.fromList([1, 2, 3, 4]);
      final state = ExportState(previewFrame: frame);
      expect(state.previewFrame, isNotNull);
      final cleared = state.copyWith(clearPreview: true);
      expect(cleared.previewFrame, isNull);
    });

    test('copyWith: 변경하지 않은 필드는 유지된다', () {
      const state = ExportState(
        status: ExportStatus.loading,
        activeAction: ExportAction.share,
        error: '에러',
        successMessage: '성공',
      );
      final updated = state.copyWith(status: ExportStatus.idle);
      expect(updated.activeAction, ExportAction.share);
      expect(updated.error, '에러');
      expect(updated.successMessage, '성공');
    });
  });

  // ── ExportStatus ───────────────────────────────────────────────
  group('ExportStatus', () {
    test('4가지 상태가 정의되어 있다', () {
      expect(ExportStatus.values.length, 4);
      expect(ExportStatus.values, containsAll([
        ExportStatus.idle,
        ExportStatus.loading,
        ExportStatus.success,
        ExportStatus.error,
      ]));
    });
  });

  // ── ExportAction ───────────────────────────────────────────────
  group('ExportAction', () {
    test('5가지 액션이 정의되어 있다', () {
      expect(ExportAction.values.length, 5);
      expect(ExportAction.values, containsAll([
        ExportAction.none,
        ExportAction.savePhoto,
        ExportAction.share,
        ExportAction.generateLoop,
        ExportAction.saveLoop,
      ]));
    });
  });

  // ── ExportNotifier 초기 상태 ────────────────────────────────────
  group('ExportNotifier 초기 상태', () {
    test('초기 상태가 idle이다', () {
      final notifier = ExportNotifier();
      expect(notifier.state.status, ExportStatus.idle);
      expect(notifier.state.activeAction, ExportAction.none);
      expect(notifier.state.previewFrame, isNull);
      expect(notifier.state.error, isNull);
    });
  });

  // ── ExportState copyWith 체이닝 ─────────────────────────────────
  group('ExportState 체이닝', () {
    test('다중 필드 동시 변경', () {
      const state = ExportState();
      final updated = state.copyWith(
        status: ExportStatus.loading,
        activeAction: ExportAction.savePhoto,
        error: '에러',
      );
      expect(updated.status, ExportStatus.loading);
      expect(updated.activeAction, ExportAction.savePhoto);
      expect(updated.error, '에러');
      expect(updated.previewFrame, isNull);
    });

    test('clearError + clearSuccess 동시 적용', () {
      const state = ExportState(error: 'e', successMessage: 's');
      final cleared = state.copyWith(clearError: true, clearSuccess: true);
      expect(cleared.error, isNull);
      expect(cleared.successMessage, isNull);
    });

    test('clearError false일 때 기존 error 유지', () {
      const state = ExportState(error: '에러');
      final updated = state.copyWith(status: ExportStatus.idle);
      expect(updated.error, '에러');
    });
  });
}
