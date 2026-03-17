import 'package:flutter_test/flutter_test.dart';
import 'package:color_pop/models/brush_settings.dart';

void main() {
  group('BrushSettings', () {
    test('기본값이 올바르게 설정된다', () {
      const settings = BrushSettings();
      expect(settings.size, 40.0);
      expect(settings.softness, 0.5);
      expect(settings.opacity, 1.0);
      expect(settings.mode, BrushMode.reveal);
    });

    test('copyWith - 개별 필드만 변경된다', () {
      const original = BrushSettings(size: 40, softness: 0.5);
      final updated = original.copyWith(size: 80);
      expect(updated.size, 80);
      expect(updated.softness, 0.5); // 변경되지 않음
      expect(updated.mode, BrushMode.reveal); // 변경되지 않음
    });

    test('copyWith - 모드 전환', () {
      const settings = BrushSettings();
      final eraseMode = settings.copyWith(mode: BrushMode.erase);
      expect(eraseMode.mode, BrushMode.erase);
    });

    test('toMap - reveal 모드', () {
      const settings = BrushSettings(size: 60, softness: 0.3, opacity: 0.8);
      final map = settings.toMap();
      expect(map['size'], 60.0);
      expect(map['softness'], 0.3);
      expect(map['opacity'], 0.8);
      expect(map['isReveal'], true);
    });

    test('toMap - erase 모드', () {
      const settings = BrushSettings(mode: BrushMode.erase);
      final map = settings.toMap();
      expect(map['isReveal'], false);
    });

    test('size는 5~150 범위 내 값을 그대로 저장한다', () {
      const small = BrushSettings(size: 5);
      const large = BrushSettings(size: 150);
      expect(small.size, 5.0);
      expect(large.size, 150.0);
    });
  });
}
