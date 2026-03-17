import 'package:flutter/services.dart';

/// com.colorpop/export Platform Channel 래퍼
class ExportService {
  static const _channel = MethodChannel('com.colorpop/export');

  /// 현재 렌더 프레임을 고화질 JPEG로 반환
  Future<Uint8List?> getExportFrame({double quality = 0.95}) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>(
        'getExportFrame',
        {'quality': quality},
      );
      return result;
    } on PlatformException {
      return null;
    }
  }

  /// 현재 편집 결과를 기기 사진함에 저장
  /// Returns: true = 성공, throws = 실패(권한 없음 등)
  Future<bool> saveToPhotos({double quality = 0.95}) async {
    final result = await _channel.invokeMethod<bool>(
      'saveToPhotos',
      {'quality': quality},
    );
    return result ?? false;
  }

  /// 시스템 공유 시트를 통해 이미지 공유
  /// Returns: true = 사용자가 공유 완료, false = 취소
  Future<bool> shareImage({double quality = 0.92}) async {
    final result = await _channel.invokeMethod<bool>(
      'shareImage',
      {'quality': quality},
    );
    return result ?? false;
  }

  /// Loop 영상(B&W→Color→B&W 3초)을 생성하여 공유 시트 표시
  Future<bool> generateAndShareLoop() async {
    final result = await _channel.invokeMethod<bool>('generateAndShareLoop');
    return result ?? false;
  }

  /// Loop 영상을 기기 사진함에 저장
  Future<bool> saveLoopToPhotos() async {
    final result = await _channel.invokeMethod<bool>('saveLoopToPhotos');
    return result ?? false;
  }
}
