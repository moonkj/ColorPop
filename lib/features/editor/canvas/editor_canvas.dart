import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/brush_settings.dart';
import '../editor_provider.dart';
import 'brush_overlay_painter.dart';

class EditorCanvas extends ConsumerStatefulWidget {
  const EditorCanvas({super.key});

  @override
  ConsumerState<EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends ConsumerState<EditorCanvas> {
  final _canvasKey = GlobalKey();
  final _transformController = TransformationController();

  // 현재 브러시 획 좌표 목록 (정규화 0~1, 이미지 공간)
  final List<Offset> _currentStrokePoints = [];
  Offset? _cursorPosition; // 화면 좌표 (커서 표시용)

  // 브러시 호출 스로틀링
  DateTime _lastBrushCall = DateTime.now();
  static const _throttleMs = 40; // ~25fps

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editorProvider);
    final isBrushMode = state.mode == EditorMode.brush;
    final isColorSelectMode = state.mode == EditorMode.colorSelect;

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── 이미지 캔버스 (줌/팬) ──────────────────────────
          InteractiveViewer(
            key: _canvasKey,
            transformationController: _transformController,
            minScale: 0.5,
            maxScale: 8.0,
            panEnabled: !isBrushMode && !isColorSelectMode,
            child: _ImageLayer(
              renderedFrame: state.renderedFrame,
              status: state.status,
            ),
          ),

          // ── 브러시 오버레이 (브러시 모드에서만) ──────────────
          if (isBrushMode) ...[
            _BrushGestureLayer(
              imageWidth: state.imageWidth,
              imageHeight: state.imageHeight,
              brushSettings: state.brushSettings,
              currentStrokePoints: _currentStrokePoints,
              cursorPosition: _cursorPosition,
              onPanStart: _onBrushStart,
              onPanUpdate: _onBrushUpdate,
              onPanEnd: _onBrushEnd,
            ),
          ],

          // ── 색상 선택 탭 오버레이 ─────────────────────────────
          if (isColorSelectMode)
            _ColorSelectGestureLayer(
              imageWidth: state.imageWidth,
              imageHeight: state.imageHeight,
              onTap: _onColorSelectTap,
            ),
        ],
      ),
    );
  }

  // ── 좌표 변환 유틸 ─────────────────────────────────────────
  /// 화면 터치 좌표 → 이미지 정규화 좌표 (0~1)
  Offset? _screenToNormalized(Offset screenPos, Size canvasSize, Size imageSize) {
    if (imageSize.width <= 0 || imageSize.height <= 0) return null;

    final imageAspect = imageSize.width / imageSize.height;
    final canvasAspect = canvasSize.width / canvasSize.height;

    double displayW, displayH, offsetX, offsetY;
    if (imageAspect > canvasAspect) {
      displayW = canvasSize.width;
      displayH = displayW / imageAspect;
      offsetX = 0;
      offsetY = (canvasSize.height - displayH) / 2;
    } else {
      displayH = canvasSize.height;
      displayW = displayH * imageAspect;
      offsetX = (canvasSize.width - displayW) / 2;
      offsetY = 0;
    }

    final localX = screenPos.dx - offsetX;
    final localY = screenPos.dy - offsetY;

    // 이미지 영역 밖이면 null 반환
    if (localX < 0 || localX > displayW || localY < 0 || localY > displayH) {
      return null;
    }

    return Offset(localX / displayW, localY / displayH);
  }

  // ── 브러시 이벤트 ─────────────────────────────────────────
  void _onBrushStart(DragStartDetails details) {
    _currentStrokePoints.clear();
    _updateBrush(details.globalPosition);
  }

  void _onBrushUpdate(DragUpdateDetails details) {
    _updateBrush(details.globalPosition);

    // 스로틀링: 40ms 간격으로 네이티브 호출
    final now = DateTime.now();
    if (now.difference(_lastBrushCall).inMilliseconds >= _throttleMs) {
      _lastBrushCall = now;
      _sendBrushToNative(details.globalPosition);
    }
  }

  void _onBrushEnd(DragEndDetails details) {
    _sendBrushToNative(null); // 마지막 지점은 이전에 이미 전송됨
    ref.read(editorProvider.notifier).endStroke();
    setState(() {
      _currentStrokePoints.clear();
      _cursorPosition = null;
    });
  }

  void _updateBrush(Offset globalPos) {
    final canvasBox = context.findRenderObject() as RenderBox?;
    if (canvasBox == null) return;

    final localPos = canvasBox.globalToLocal(globalPos);
    final canvasSize = canvasBox.size;
    final state = ref.read(editorProvider);
    final imageSize = Size(
      state.imageWidth.toDouble(),
      state.imageHeight.toDouble(),
    );

    final normalized = _screenToNormalized(localPos, canvasSize, imageSize);
    if (normalized != null) {
      setState(() {
        _currentStrokePoints.add(normalized);
        _cursorPosition = localPos;
      });
    }
  }

  void _sendBrushToNative(Offset? globalPos) {
    if (_currentStrokePoints.isEmpty) return;
    final last = _currentStrokePoints.last;
    ref.read(editorProvider.notifier).paintBrush(last.dx, last.dy);
  }

  // ── 색상 선택 이벤트 ──────────────────────────────────────────
  void _onColorSelectTap(Offset localPos, Size canvasSize) {
    final state = ref.read(editorProvider);
    final imageSize = Size(
      state.imageWidth.toDouble(),
      state.imageHeight.toDouble(),
    );
    final normalized = _screenToNormalized(localPos, canvasSize, imageSize);
    if (normalized == null) return;
    ref.read(editorProvider.notifier).sampleAndApplyColor(
          normalizedX: normalized.dx,
          normalizedY: normalized.dy,
        );
  }
}

// ── 이미지 레이어 ──────────────────────────────────────────────
class _ImageLayer extends StatelessWidget {
  final Uint8List? renderedFrame;
  final EditorStatus status;

  const _ImageLayer({required this.renderedFrame, required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == EditorStatus.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (status == EditorStatus.error) {
      return const Center(
        child: Icon(Icons.error_outline, color: AppColors.error, size: 48),
      );
    }

    if (renderedFrame == null) {
      return const Center(
        child: Icon(Icons.image_outlined, color: AppColors.textTertiary, size: 64),
      );
    }

    return Image.memory(
      renderedFrame!,
      fit: BoxFit.contain,
      gaplessPlayback: true, // 프레임 전환 시 깜빡임 방지
    );
  }
}

// ── 색상 선택 제스처 레이어 ─────────────────────────────────────

class _ColorSelectGestureLayer extends StatelessWidget {
  final int imageWidth;
  final int imageHeight;
  final void Function(Offset localPos, Size canvasSize) onTap;

  const _ColorSelectGestureLayer({
    required this.imageWidth,
    required this.imageHeight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => onTap(d.localPosition, canvasSize),
          child: MouseRegion(
            cursor: SystemMouseCursors.precise,
            child: Container(color: Colors.transparent),
          ),
        );
      },
    );
  }
}

// ── 브러시 제스처 레이어 ────────────────────────────────────────
class _BrushGestureLayer extends StatelessWidget {
  final int imageWidth;
  final int imageHeight;
  final BrushSettings brushSettings;
  final List<Offset> currentStrokePoints;
  final Offset? cursorPosition;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;

  const _BrushGestureLayer({
    required this.imageWidth,
    required this.imageHeight,
    required this.brushSettings,
    required this.currentStrokePoints,
    required this.cursorPosition,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
        final imageSize = Size(imageWidth.toDouble(), imageHeight.toDouble());

        // 이미지 표시 영역 계산 (BoxFit.contain 기준)
        final imageDisplayRect = _calcImageDisplayRect(canvasSize, imageSize);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: onPanStart,
          onPanUpdate: onPanUpdate,
          onPanEnd: onPanEnd,
          child: CustomPaint(
            painter: BrushOverlayPainter(
              points: currentStrokePoints,
              settings: brushSettings,
              imageDisplaySize: imageDisplayRect.size,
              imageDisplayOffset: imageDisplayRect.topLeft,
            ),
            foregroundPainter: BrushCursorPainter(
              position: cursorPosition,
              radius: brushSettings.size * 0.5 *
                  (imageDisplayRect.width / (imageWidth > 0 ? imageWidth : 1)),
              mode: brushSettings.mode,
            ),
          ),
        );
      },
    );
  }

  Rect _calcImageDisplayRect(Size canvasSize, Size imageSize) {
    if (imageSize.width <= 0 || imageSize.height <= 0) {
      return Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height);
    }
    final imageAspect = imageSize.width / imageSize.height;
    final canvasAspect = canvasSize.width / canvasSize.height;

    double displayW, displayH, offsetX, offsetY;
    if (imageAspect > canvasAspect) {
      displayW = canvasSize.width;
      displayH = displayW / imageAspect;
      offsetX = 0;
      offsetY = (canvasSize.height - displayH) / 2;
    } else {
      displayH = canvasSize.height;
      displayW = displayH * imageAspect;
      offsetX = (canvasSize.width - displayW) / 2;
      offsetY = 0;
    }
    return Rect.fromLTWH(offsetX, offsetY, displayW, displayH);
  }
}
