import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/camera_service.dart';

enum CameraStatus { idle, initializing, ready, capturing, error }
enum CameraFacing { back, front }

// ── 상태 ───────────────────────────────────────────────────────
class CameraState {
  final CameraStatus status;
  final int textureId;
  final bool hasLiDAR;
  final CameraFacing facing;
  final bool isInverseMode;
  final String? error;

  const CameraState({
    this.status = CameraStatus.idle,
    this.textureId = -1,
    this.hasLiDAR = false,
    this.facing = CameraFacing.back,
    this.isInverseMode = false,
    this.error,
  });

  bool get isReady => status == CameraStatus.ready;
  bool get isCapturing => status == CameraStatus.capturing;

  CameraState copyWith({
    CameraStatus? status,
    int? textureId,
    bool? hasLiDAR,
    CameraFacing? facing,
    bool? isInverseMode,
    String? error,
  }) {
    return CameraState(
      status: status ?? this.status,
      textureId: textureId ?? this.textureId,
      hasLiDAR: hasLiDAR ?? this.hasLiDAR,
      facing: facing ?? this.facing,
      isInverseMode: isInverseMode ?? this.isInverseMode,
      error: error,
    );
  }
}

// ── Provider ───────────────────────────────────────────────────
final cameraProvider = NotifierProvider<CameraNotifier, CameraState>(
  CameraNotifier.new,
);

class CameraNotifier extends Notifier<CameraState> {
  final _service = CameraService();

  @override
  CameraState build() => const CameraState();

  /// 카메라 초기화 (FlutterTexture 등록 포함)
  Future<void> initCamera() async {
    state = state.copyWith(status: CameraStatus.initializing);
    try {
      final result = await _service.initCamera(
        position: state.facing == CameraFacing.back ? 'back' : 'front',
      );
      state = state.copyWith(
        status: CameraStatus.ready,
        textureId: result['textureId'] as int,
        hasLiDAR: result['hasLiDAR'] as bool,
      );
    } catch (e) {
      state = state.copyWith(
        status: CameraStatus.error,
        error: '카메라를 시작할 수 없습니다: $e',
      );
    }
  }

  /// 카메라 세션 종료
  Future<void> disposeCamera() async {
    await _service.disposeCamera();
    state = const CameraState();
  }

  /// 전면/후면 전환
  Future<void> switchCamera() async {
    final newFacing =
        state.facing == CameraFacing.back ? CameraFacing.front : CameraFacing.back;
    state = state.copyWith(facing: newFacing);
    await _service.switchCamera();
  }

  /// 반전 모드 토글
  Future<void> toggleInverseMode() async {
    final next = !state.isInverseMode;
    state = state.copyWith(isInverseMode: next);
    await _service.setInverseMode(next);
  }

  /// 사진 촬영 → JPEG bytes 반환 (null이면 실패)
  Future<Uint8List?> capturePhoto() async {
    if (!state.isReady) return null;
    state = state.copyWith(status: CameraStatus.capturing);
    try {
      final data = await _service.capturePhoto();
      state = state.copyWith(status: CameraStatus.ready);
      return data;
    } catch (e) {
      state = state.copyWith(
        status: CameraStatus.ready,
        error: '촬영에 실패했습니다: $e',
      );
      return null;
    }
  }
}
