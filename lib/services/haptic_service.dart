import 'package:flutter/services.dart';

/// 앱 전역 햅틱 피드백 중앙 관리
/// Flutter HapticFeedback + iOS SoundChannel 햅틱을 통합 제어
class HapticService {
  HapticService._();

  static const _channel = MethodChannel('com.colorpop/sound');

  // ── Flutter 기본 햅틱 (크로스플랫폼) ────────────────────────────

  /// 버튼 탭, 아이템 선택 — 가벼운 터치
  static Future<void> light() => HapticFeedback.lightImpact();

  /// 모드 전환, 확인 — 중간 터치
  static Future<void> medium() => HapticFeedback.mediumImpact();

  /// 삭제, 강조 액션 — 강한 터치
  static Future<void> heavy() => HapticFeedback.heavyImpact();

  /// 리스트 스크롤 — 선택 틱
  static Future<void> selection() => HapticFeedback.selectionClick();

  // ── iOS 네이티브 알림 햅틱 (SoundChannel) ────────────────────────

  /// 저장/AI완료 — 성공 알림 진동 (3연타)
  static Future<void> success() async {
    try {
      await _channel.invokeMethod('notifySuccess');
    } on PlatformException {
      await HapticFeedback.mediumImpact();
    }
  }

  /// 에러 — 에러 알림 진동
  static Future<void> error() async {
    try {
      await _channel.invokeMethod('notifyError');
    } on PlatformException {
      await HapticFeedback.heavyImpact();
    }
  }

  /// 드래그 핸들, 슬라이더 — 선택 변경 틱
  static Future<void> selectionChanged() async {
    try {
      await _channel.invokeMethod('selectionChanged');
    } on PlatformException {
      await HapticFeedback.selectionClick();
    }
  }
}
