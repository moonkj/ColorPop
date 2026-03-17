import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/export_service.dart';

enum ExportStatus { idle, loading, success, error }

enum ExportAction { none, savePhoto, share, generateLoop, saveLoop }

class ExportState {
  final ExportStatus status;
  final ExportAction activeAction;
  final Uint8List? previewFrame;   // 내보내기용 고화질 프리뷰
  final String? error;
  final String? successMessage;

  const ExportState({
    this.status = ExportStatus.idle,
    this.activeAction = ExportAction.none,
    this.previewFrame,
    this.error,
    this.successMessage,
  });

  bool get isLoading => status == ExportStatus.loading;

  ExportState copyWith({
    ExportStatus? status,
    ExportAction? activeAction,
    Uint8List? previewFrame,
    bool clearPreview = false,
    String? error,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return ExportState(
      status:         status ?? this.status,
      activeAction:   activeAction ?? this.activeAction,
      previewFrame:   clearPreview ? null : (previewFrame ?? this.previewFrame),
      error:          clearError   ? null : (error ?? this.error),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────
class ExportNotifier extends StateNotifier<ExportState> {
  ExportNotifier() : super(const ExportState());

  final _service = ExportService();

  /// 화면 진입 시 고화질 프리뷰 프레임 로드
  Future<void> loadPreview() async {
    state = state.copyWith(status: ExportStatus.loading, activeAction: ExportAction.none);
    final frame = await _service.getExportFrame(quality: 0.95);
    state = state.copyWith(
      status: frame != null ? ExportStatus.idle : ExportStatus.error,
      previewFrame: frame,
      error: frame == null ? '미리보기 로드 실패' : null,
    );
  }

  /// 현재 편집 결과를 Photos에 저장
  Future<void> saveToPhotos() async {
    if (state.isLoading) return;
    state = state.copyWith(
      status: ExportStatus.loading,
      activeAction: ExportAction.savePhoto,
      clearError: true,
      clearSuccess: true,
    );
    try {
      final success = await _service.saveToPhotos(quality: 0.97);
      state = state.copyWith(
        status: ExportStatus.success,
        activeAction: ExportAction.none,
        successMessage: success ? '사진이 저장되었습니다' : null,
        error: success ? null : '저장에 실패했습니다',
      );
    } on PlatformException catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        activeAction: ExportAction.none,
        error: e.message ?? '저장 실패',
      );
    }
  }

  /// 시스템 공유 시트 표시
  Future<void> shareImage() async {
    if (state.isLoading) return;
    state = state.copyWith(
      status: ExportStatus.loading,
      activeAction: ExportAction.share,
      clearError: true,
      clearSuccess: true,
    );
    try {
      await _service.shareImage(quality: 0.92);
      state = state.copyWith(
        status: ExportStatus.idle,
        activeAction: ExportAction.none,
      );
    } on PlatformException catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        activeAction: ExportAction.none,
        error: e.message ?? '공유 실패',
      );
    }
  }

  /// Loop 영상 생성 후 공유
  Future<void> generateAndShareLoop() async {
    if (state.isLoading) return;
    state = state.copyWith(
      status: ExportStatus.loading,
      activeAction: ExportAction.generateLoop,
      clearError: true,
      clearSuccess: true,
    );
    try {
      await _service.generateAndShareLoop();
      state = state.copyWith(
        status: ExportStatus.idle,
        activeAction: ExportAction.none,
      );
    } on PlatformException catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        activeAction: ExportAction.none,
        error: e.message ?? 'Loop 영상 생성 실패',
      );
    }
  }

  /// Loop 영상 Photos에 저장
  Future<void> saveLoopToPhotos() async {
    if (state.isLoading) return;
    state = state.copyWith(
      status: ExportStatus.loading,
      activeAction: ExportAction.saveLoop,
      clearError: true,
      clearSuccess: true,
    );
    try {
      final success = await _service.saveLoopToPhotos();
      state = state.copyWith(
        status: ExportStatus.success,
        activeAction: ExportAction.none,
        successMessage: success ? 'Loop 영상이 저장되었습니다' : null,
        error: success ? null : '저장에 실패했습니다',
      );
    } on PlatformException catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        activeAction: ExportAction.none,
        error: e.message ?? 'Loop 영상 저장 실패',
      );
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

// ── Provider ────────────────────────────────────────────────────
final exportProvider = StateNotifierProvider<ExportNotifier, ExportState>(
  (_) => ExportNotifier(),
);
