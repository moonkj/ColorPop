import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../models/detected_object.dart';
import '../models/ai_suggestion.dart';

/// com.colorpop/ai Platform Channel 래퍼
class AiSegmentationService {
  static const _channel = MethodChannel('com.colorpop/ai');

  // ── 이미지 전체 AI 분석 ────────────────────────────────────────
  /// 객체 감지 + 씬 분류 + AI 추천을 한 번에 수행한다
  /// 반환: { objects: [DetectedObject], suggestions: [AiSuggestion] }
  Future<({List<DetectedObject> objects, List<AiSuggestion> suggestions})?>
      analyzeImage() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('analyzeImage');
      if (result == null) return null;

      final rawObjects = result['objects'] as List<dynamic>? ?? [];
      final rawSuggestions = result['suggestions'] as List<dynamic>? ?? [];

      final objects = rawObjects
          .whereType<Map>()
          .map((m) => DetectedObject.fromMap(Map<String, dynamic>.from(m)))
          .toList();

      final suggestions = rawSuggestions
          .whereType<Map>()
          .map((m) => AiSuggestion.fromMap(Map<String, dynamic>.from(m)))
          .toList();

      return (objects: objects, suggestions: suggestions);
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('analyzeImage error: ${e.code} - ${e.message}');
      return null;
    }
  }

  // ── 인물 세그멘테이션 ───────────────────────────────────────────
  /// VNGeneratePersonSegmentationRequest로 인물 마스크를 적용한다
  /// 반환: 렌더링된 JPEG bytes
  Future<Uint8List?> applyPersonSegmentation() async {
    try {
      return await _channel.invokeMethod<Uint8List>('applyPersonSegmentation');
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('applyPersonSegmentation error: ${e.code} - ${e.message}');
      return null;
    }
  }

  // ── 특정 객체 마스크 적용 ────────────────────────────────────────
  /// 감지된 객체(label)의 마스크를 적용한다
  /// 반환: 렌더링된 JPEG bytes
  Future<Uint8List?> applyObjectMask(String label) async {
    try {
      return await _channel.invokeMethod<Uint8List>(
        'applyObjectMask',
        {'label': label},
      );
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('applyObjectMask error: ${e.code} - ${e.message}');
      return null;
    }
  }

  // ── 비-피사체 전체 선택 ──────────────────────────────────────────
  /// 인물 마스크를 반전시켜 배경 전체를 컬러로 선택한다
  /// 반환: 렌더링된 JPEG bytes
  Future<Uint8List?> applyNonSubjectMask() async {
    try {
      return await _channel.invokeMethod<Uint8List>('applyNonSubjectMask');
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('applyNonSubjectMask error: ${e.code} - ${e.message}');
      return null;
    }
  }
}
