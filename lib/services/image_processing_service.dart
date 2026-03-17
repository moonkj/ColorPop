import 'package:flutter/services.dart';
import '../models/brush_settings.dart';
import '../models/color_selection.dart';
import '../models/effect_config.dart';

class ImageProcessingService {
  static const _channel = MethodChannel('com.colorpop/image');

  // ── Phase 1 ────────────────────────────────────────────────
  Future<Uint8List?> convertToGrayscale(Uint8List imageData) async {
    try {
      return await _channel.invokeMethod<Uint8List>(
        'processGrayscale',
        {'imageData': imageData},
      );
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('convertToGrayscale error: ${e.code} - ${e.message}');
      return null;
    }
  }

  // ── Phase 2: 편집 세션 초기화 ───────────────────────────────
  /// 네이티브 Metal 세션 생성. 반환: {frame, width, height}
  Future<Map<String, dynamic>?> initEditor(Uint8List imageData) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'initEditor',
        {'imageData': imageData},
      );
      return result;
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('initEditor error: ${e.code} - ${e.message}');
      return null;
    }
  }

  // ── Phase 2: 브러시 스트로크 ────────────────────────────────
  /// 정규화 좌표(0-1)와 브러시 설정을 전달. 반환: 렌더링된 JPEG bytes
  Future<Uint8List?> paintBrush({
    required double normalizedX,
    required double normalizedY,
    required BrushSettings settings,
  }) async {
    try {
      return await _channel.invokeMethod<Uint8List>(
        'paintBrush',
        {
          'x': normalizedX,
          'y': normalizedY,
          ...settings.toMap(),
        },
      );
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('paintBrush error: ${e.code} - ${e.message}');
      return null;
    }
  }

  // ── Phase 2: 획 종료 (Undo 스냅샷 트리거) ───────────────────
  Future<void> endStroke() async {
    try {
      await _channel.invokeMethod('endStroke');
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('endStroke error: ${e.code}');
    }
  }

  // ── Phase 2: Undo / Redo ────────────────────────────────────
  Future<Uint8List?> undo() async {
    try {
      return await _channel.invokeMethod<Uint8List>('undoMask');
    } on PlatformException {
      return null;
    }
  }

  Future<Uint8List?> redo() async {
    try {
      return await _channel.invokeMethod<Uint8List>('redoMask');
    } on PlatformException {
      return null;
    }
  }

  // ── Phase 4: 색상 선택 ─────────────────────────────────────────

  /// 정규화 좌표에서 픽셀의 HSL 정보를 추출한다
  Future<ColorSelection?> samplePixelColor({
    required double normalizedX,
    required double normalizedY,
  }) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'samplePixelColor',
        {'x': normalizedX, 'y': normalizedY},
      );
      if (result == null) return null;
      final isGrayscale = result['isGrayscale'] as bool? ?? false;
      if (isGrayscale) return null; // 무채색은 null로 반환해 UI에서 경고 처리
      return ColorSelection.fromMap(result);
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('samplePixelColor error: ${e.code}');
      return null;
    }
  }

  /// HSL 단일 색상 마스크 적용. 반환: JPEG bytes
  Future<Uint8List?> applyColorSelection(ColorSelection selection) async {
    try {
      return await _channel.invokeMethod<Uint8List>(
        'applyColorSelection',
        {
          'h': selection.h,
          's': selection.s,
          'tolerance': selection.tolerance,
        },
      );
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('applyColorSelection error: ${e.code}');
      return null;
    }
  }

  // ── Phase 5: 이펙트 ──────────────────────────────────────────────

  /// 이펙트 타입 + 강도 적용. 반환: JPEG bytes
  Future<Uint8List?> setEffect(EffectConfig config) async {
    try {
      return await _channel.invokeMethod<Uint8List>(
        'setEffect',
        {'effectType': config.typeString, 'intensity': config.intensity},
      );
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('setEffect error: ${e.code}');
      return null;
    }
  }

  /// 반전 모드 설정. 반환: JPEG bytes
  Future<Uint8List?> setInverseMode(bool isInverse) async {
    try {
      return await _channel.invokeMethod<Uint8List>(
        'setInverseMode',
        {'isInverse': isInverse},
      );
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('setInverseMode error: ${e.code}');
      return null;
    }
  }

  /// 그라디언트 범위 색상 마스크 적용 (B-6). 반환: JPEG bytes
  Future<Uint8List?> applyColorRangeSelection(ColorSelection selection) async {
    if (selection.rangeEndH == null) return applyColorSelection(selection);
    try {
      return await _channel.invokeMethod<Uint8List>(
        'applyColorRangeSelection',
        {
          'hFrom': selection.h,
          'hTo': selection.rangeEndH,
          'tolerance': selection.tolerance,
        },
      );
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('applyColorRangeSelection error: ${e.code}');
      return null;
    }
  }
}
