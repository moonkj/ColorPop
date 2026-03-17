import 'package:flutter/services.dart';

/// iOS 마이크로 인터랙션 사운드 디자인 서비스 (B-12)
/// com.colorpop/sound Platform Channel 래퍼
class SoundService {
  SoundService._();

  static const _channel = MethodChannel('com.colorpop/sound');

  static Future<void> _play(String method) async {
    try {
      await _channel.invokeMethod(method);
    } on PlatformException {
      // 사운드 실패는 무시 (핵심 기능 아님)
    }
  }

  /// 브러시 첫 획 시작 — 틱
  static Future<void> brushStart() => _play('playBrushStart');

  /// AI 세그멘테이션 완료 — 차임
  static Future<void> aiComplete() => _play('playAiComplete');

  /// 사진 저장 성공 — 팝
  static Future<void> saveSuccess() => _play('playSaveSuccess');

  /// 공유 완료 — 전송 사운드
  static Future<void> shareSuccess() => _play('playShareSuccess');

  /// 색상 선택 — 틱
  static Future<void> colorSelect() => _play('playColorSelect');

  /// 에러
  static Future<void> errorSound() => _play('playError');
}
