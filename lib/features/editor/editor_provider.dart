import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/edit_item.dart';
import '../../models/brush_settings.dart';
import '../../models/detected_object.dart';
import '../../models/ai_suggestion.dart';
import '../../models/color_selection.dart';
import '../../models/effect_config.dart';
import '../../services/image_processing_service.dart';
import '../../services/ai_segmentation_service.dart';

enum EditorMode { brush, colorSelect, aiObject, effects }
enum EditorStatus { idle, loading, ready, error }

// ── 상태 ───────────────────────────────────────────────────────
class EditorState {
  final EditItem? currentItem;
  final Uint8List? renderedFrame;
  final Uint8List? originalBytes;
  final int imageWidth;
  final int imageHeight;
  final EditorMode mode;
  final EditorStatus status;
  final BrushSettings brushSettings;
  final bool canUndo;
  final bool canRedo;
  final String? error;

  // Phase 3: AI
  final List<DetectedObject> detectedObjects;
  final List<AiSuggestion> aiSuggestions;
  final DetectedObject? selectedObject;
  final bool isAiAnalyzing;
  final bool isAiApplying;

  // Phase 4: 색상 선택
  final ColorSelection? colorSelection;
  final ColorSelection? colorRangeEndSelection;
  final bool isColorRangeMode;
  final bool isColorApplying;

  // Phase 5: 이펙트
  final EffectConfig effectConfig;
  final bool isInverseMode;

  const EditorState({
    this.currentItem,
    this.renderedFrame,
    this.originalBytes,
    this.imageWidth = 0,
    this.imageHeight = 0,
    this.mode = EditorMode.brush,
    this.status = EditorStatus.idle,
    this.brushSettings = const BrushSettings(),
    this.canUndo = false,
    this.canRedo = false,
    this.error,
    this.detectedObjects = const [],
    this.aiSuggestions = const [],
    this.selectedObject,
    this.isAiAnalyzing = false,
    this.isAiApplying = false,
    this.colorSelection,
    this.colorRangeEndSelection,
    this.isColorRangeMode = false,
    this.isColorApplying = false,
    this.effectConfig = const EffectConfig(),
    this.isInverseMode = false,
  });

  EditorState copyWith({
    EditItem? currentItem,
    Uint8List? renderedFrame,
    Uint8List? originalBytes,
    int? imageWidth,
    int? imageHeight,
    EditorMode? mode,
    EditorStatus? status,
    BrushSettings? brushSettings,
    bool? canUndo,
    bool? canRedo,
    String? error,
    List<DetectedObject>? detectedObjects,
    List<AiSuggestion>? aiSuggestions,
    DetectedObject? selectedObject,
    bool clearSelectedObject = false,
    bool? isAiAnalyzing,
    bool? isAiApplying,
    ColorSelection? colorSelection,
    bool clearColorSelection = false,
    ColorSelection? colorRangeEndSelection,
    bool clearColorRangeEnd = false,
    bool? isColorRangeMode,
    bool? isColorApplying,
    EffectConfig? effectConfig,
    bool? isInverseMode,
  }) {
    return EditorState(
      currentItem: currentItem ?? this.currentItem,
      renderedFrame: renderedFrame ?? this.renderedFrame,
      originalBytes: originalBytes ?? this.originalBytes,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
      mode: mode ?? this.mode,
      status: status ?? this.status,
      brushSettings: brushSettings ?? this.brushSettings,
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
      error: error,
      detectedObjects: detectedObjects ?? this.detectedObjects,
      aiSuggestions: aiSuggestions ?? this.aiSuggestions,
      selectedObject: clearSelectedObject ? null : (selectedObject ?? this.selectedObject),
      isAiAnalyzing: isAiAnalyzing ?? this.isAiAnalyzing,
      isAiApplying: isAiApplying ?? this.isAiApplying,
      colorSelection: clearColorSelection ? null : (colorSelection ?? this.colorSelection),
      colorRangeEndSelection: clearColorRangeEnd
          ? null
          : (colorRangeEndSelection ?? this.colorRangeEndSelection),
      isColorRangeMode: isColorRangeMode ?? this.isColorRangeMode,
      isColorApplying: isColorApplying ?? this.isColorApplying,
      effectConfig: effectConfig ?? this.effectConfig,
      isInverseMode: isInverseMode ?? this.isInverseMode,
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────
class EditorNotifier extends StateNotifier<EditorState> {
  EditorNotifier() : super(const EditorState());

  final _imageService = ImageProcessingService();
  final _aiService = AiSegmentationService();

  Timer? _toleranceTimer;
  Timer? _effectTimer;

  @override
  void dispose() {
    _toleranceTimer?.cancel();
    _effectTimer?.cancel();
    super.dispose();
  }

  // ── 이미지 로드 ────────────────────────────────────────────────

  Future<void> loadImage(EditItem item) async {
    state = state.copyWith(
      currentItem: item,
      status: EditorStatus.loading,
    );
    try {
      final bytes = await File(item.imagePath).readAsBytes();
      final result = await _imageService.initEditor(bytes);
      if (result == null) {
        state = state.copyWith(status: EditorStatus.error, error: '이미지 초기화 실패');
        return;
      }
      final frame = result['frame'];
      final width = result['width'] as int? ?? 0;
      final height = result['height'] as int? ?? 0;
      state = state.copyWith(
        originalBytes: bytes,
        renderedFrame: frame is Uint8List ? frame : null,
        imageWidth: width,
        imageHeight: height,
        status: EditorStatus.ready,
        canUndo: false,
        canRedo: false,
      );
    } catch (e) {
      state = state.copyWith(status: EditorStatus.error, error: '이미지 로드 실패: $e');
    }
  }

  // ── 브러시 ─────────────────────────────────────────────────────

  Future<void> paintBrush(double x, double y) async {
    if (state.status != EditorStatus.ready) return;
    final frame = await _imageService.paintBrush(
      normalizedX: x,
      normalizedY: y,
      settings: state.brushSettings,
    );
    if (frame != null) state = state.copyWith(renderedFrame: frame);
  }

  Future<void> endStroke() async {
    await _imageService.endStroke();
    state = state.copyWith(canUndo: true, canRedo: false);
  }

  Future<void> undo() async {
    final frame = await _imageService.undo();
    if (frame != null) state = state.copyWith(renderedFrame: frame, canRedo: true);
  }

  Future<void> redo() async {
    final frame = await _imageService.redo();
    if (frame != null) state = state.copyWith(renderedFrame: frame);
  }

  // ── Phase 3: AI ────────────────────────────────────────────────

  Future<void> analyzeImage() async {
    if (state.status != EditorStatus.ready || state.isAiAnalyzing) return;
    state = state.copyWith(
      isAiAnalyzing: true,
      detectedObjects: [],
      aiSuggestions: [],
      clearSelectedObject: true,
    );
    final result = await _aiService.analyzeImage();
    if (result == null) {
      state = state.copyWith(isAiAnalyzing: false, error: 'AI 분석 실패');
      return;
    }
    state = state.copyWith(
      isAiAnalyzing: false,
      detectedObjects: result.objects,
      aiSuggestions: result.suggestions,
      error: null,
    );
  }

  Future<void> applyObjectMask(DetectedObject object) async {
    if (state.isAiApplying) return;
    state = state.copyWith(isAiApplying: true, selectedObject: object);
    final Uint8List? frame;
    if (object.maskType == 'person') {
      frame = await _aiService.applyPersonSegmentation();
    } else if (object.maskType == 'inverted') {
      frame = await _aiService.applyNonSubjectMask();
    } else {
      frame = await _aiService.applyObjectMask(object.label);
    }
    state = state.copyWith(
      isAiApplying: false,
      renderedFrame: frame ?? state.renderedFrame,
      canUndo: frame != null ? true : state.canUndo,
      canRedo: false,
      error: frame == null ? '마스크 적용 실패' : null,
    );
  }

  Future<void> applySuggestion(AiSuggestion suggestion) async {
    if (state.isAiApplying) return;
    state = state.copyWith(isAiApplying: true);
    final label = suggestion.maskLabel;
    final Uint8List? frame;
    if (label == 'person') {
      frame = await _aiService.applyPersonSegmentation();
    } else {
      frame = await _aiService.applyObjectMask(label);
    }
    state = state.copyWith(
      isAiApplying: false,
      renderedFrame: frame ?? state.renderedFrame,
      canUndo: frame != null ? true : state.canUndo,
      canRedo: false,
      error: frame == null ? '추천 적용 실패' : null,
    );
  }

  // ── Phase 4: 색상 선택 ──────────────────────────────────────────

  /// 이미지 탭 → 픽셀 샘플링 → 즉시 마스크 적용
  Future<void> sampleAndApplyColor({
    required double normalizedX,
    required double normalizedY,
  }) async {
    if (state.status != EditorStatus.ready || state.isColorApplying) return;

    final sampled = await _imageService.samplePixelColor(
      normalizedX: normalizedX,
      normalizedY: normalizedY,
    );

    if (sampled == null) {
      // 무채색이거나 샘플링 실패
      state = state.copyWith(error: '색상을 인식할 수 없어요. 다른 영역을 탭해보세요');
      return;
    }

    // 그라디언트 범위 모드: 두 번째 탭이면 rangeEnd 설정
    if (state.isColorRangeMode && state.colorSelection != null) {
      state = state.copyWith(colorRangeEndSelection: sampled);
      await _applyCurrentColorMask();
      return;
    }

    // 일반 모드: 새 색상 선택
    state = state.copyWith(
      colorSelection: sampled,
      clearColorRangeEnd: true,
    );
    await _applyCurrentColorMask();
  }

  /// Tolerance 슬라이더 변경 → 300ms 디바운스 후 마스크 재적용
  void updateColorTolerance(double percent) {
    if (state.colorSelection == null) return;
    final newTolerance = ColorSelection.toleranceFromPercent(percent);
    final updated = state.colorSelection!.copyWith(tolerance: newTolerance);
    state = state.copyWith(colorSelection: updated);

    _toleranceTimer?.cancel();
    _toleranceTimer = Timer(const Duration(milliseconds: 300), () {
      _applyCurrentColorMask();
    });
  }

  /// 그라디언트 범위 모드 토글 (B-6)
  void toggleColorRangeMode() {
    final newRangeMode = !state.isColorRangeMode;
    state = state.copyWith(
      isColorRangeMode: newRangeMode,
      clearColorRangeEnd: true,
    );
    // 범위 모드 해제 시 단일 색상으로 재적용
    if (!newRangeMode && state.colorSelection != null) {
      _applyCurrentColorMask();
    }
  }

  Future<void> _applyCurrentColorMask() async {
    final sel = state.colorSelection;
    if (sel == null || state.isColorApplying) return;

    state = state.copyWith(isColorApplying: true);

    final Uint8List? frame;
    if (state.isColorRangeMode && state.colorRangeEndSelection != null) {
      frame = await _imageService.applyColorRangeSelection(
        sel.copyWith(rangeEndH: state.colorRangeEndSelection!.h),
      );
    } else {
      frame = await _imageService.applyColorSelection(sel);
    }

    state = state.copyWith(
      isColorApplying: false,
      renderedFrame: frame ?? state.renderedFrame,
      canUndo: frame != null ? true : state.canUndo,
      canRedo: false,
      error: frame == null ? '색상 마스크 적용 실패' : null,
    );
  }

  // ── 공통 ───────────────────────────────────────────────────────

  void setMode(EditorMode mode) {
    state = state.copyWith(mode: mode);
    if (mode == EditorMode.aiObject &&
        state.detectedObjects.isEmpty &&
        !state.isAiAnalyzing) {
      analyzeImage();
    }
    // 색상 모드 이탈 시 선택 초기화
    if (mode != EditorMode.colorSelect) {
      state = state.copyWith(
        clearColorSelection: true,
        clearColorRangeEnd: true,
        isColorRangeMode: false,
      );
    }
  }

  void updateBrushSettings(BrushSettings settings) =>
      state = state.copyWith(brushSettings: settings);

  // ── Phase 5: 이펙트 ─────────────────────────────────────────────

  /// 이펙트 타입 변경 → 즉시 적용
  Future<void> setEffectType(EffectType type) async {
    if (state.status != EditorStatus.ready) return;
    _effectTimer?.cancel();
    final newConfig = state.effectConfig.copyWith(type: type);
    state = state.copyWith(effectConfig: newConfig);
    final frame = await _imageService.setEffect(newConfig);
    if (frame != null) state = state.copyWith(renderedFrame: frame);
  }

  /// 강도 슬라이더 변경 → 200ms 디바운스 후 적용
  void updateEffectIntensity(double intensity) {
    final newConfig = state.effectConfig.copyWith(intensity: intensity);
    state = state.copyWith(effectConfig: newConfig);
    _effectTimer?.cancel();
    _effectTimer = Timer(const Duration(milliseconds: 200), () {
      _applyCurrentEffect();
    });
  }

  Future<void> _applyCurrentEffect() async {
    final frame = await _imageService.setEffect(state.effectConfig);
    if (frame != null) state = state.copyWith(renderedFrame: frame);
  }

  /// 반전 모드 토글
  Future<void> toggleInverseMode() async {
    if (state.status != EditorStatus.ready) return;
    final newInverse = !state.isInverseMode;
    state = state.copyWith(isInverseMode: newInverse);
    final frame = await _imageService.setInverseMode(newInverse);
    if (frame != null) state = state.copyWith(renderedFrame: frame);
  }

  void reset() {
    _toleranceTimer?.cancel();
    _effectTimer?.cancel();
    state = const EditorState();
  }
}

// ── Provider ───────────────────────────────────────────────────
final editorProvider = StateNotifierProvider<EditorNotifier, EditorState>(
  (_) => EditorNotifier(),
);
