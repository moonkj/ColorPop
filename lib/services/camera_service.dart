import 'package:flutter/services.dart';

/// 카메라 Platform Channel 래퍼 (com.colorpop/camera)
class CameraService {
  static const _channel = MethodChannel('com.colorpop/camera');

  /// 카메라 초기화 + FlutterTexture 등록
  /// 반환: { textureId: int, hasLiDAR: bool }
  Future<Map<String, dynamic>> initCamera({String position = 'back'}) async {
    final result = await _channel.invokeMethod<Map>('initCamera', {
      'position': position,
    });
    return {
      'textureId': result?['textureId'] as int? ?? -1,
      'hasLiDAR': result?['hasLiDAR'] as bool? ?? false,
    };
  }

  /// 카메라 세션 종료 + 텍스처 해제
  Future<void> disposeCamera() async {
    await _channel.invokeMethod('disposeCamera');
  }

  /// 전면/후면 카메라 전환
  Future<void> switchCamera() async {
    await _channel.invokeMethod('switchCamera');
  }

  /// 반전 모드 설정 (피사체↔배경 교환)
  Future<void> setInverseMode(bool isInverse) async {
    await _channel.invokeMethod('setInverseMode', {'isInverse': isInverse});
  }

  /// 사진 촬영 → JPEG Data 반환
  Future<Uint8List?> capturePhoto() async {
    final result = await _channel.invokeMethod<Uint8List>('capturePhoto');
    return result;
  }
}
