import 'package:flutter_test/flutter_test.dart';
import 'package:color_pop/models/effect_config.dart';

void main() {
  group('EffectType', () {
    test('모든 타입이 정의되어 있다', () {
      expect(EffectType.values.length, 6);
      expect(EffectType.values, containsAll([
        EffectType.none, EffectType.neonGlow, EffectType.chromatic,
        EffectType.filmGrain, EffectType.bgBlur, EffectType.filmNoir,
      ]));
    });

    test('typeString이 채널 전달용 소문자 카멜케이스를 반환한다', () {
      final config = EffectConfig(type: EffectType.neonGlow, intensity: 0.5);
      expect(config.typeString, 'neonGlow');
    });

    test('모든 타입의 typeString이 name과 일치한다', () {
      for (final t in EffectType.values) {
        final config = EffectConfig(type: t);
        expect(config.typeString, t.name);
      }
    });
  });

  group('EffectConfig', () {
    test('기본값 검증', () {
      const config = EffectConfig();
      expect(config.type, EffectType.none);
      expect(config.intensity, 0.5);
    });

    test('copyWith - type만 변경', () {
      const config = EffectConfig(type: EffectType.none, intensity: 0.7);
      final updated = config.copyWith(type: EffectType.filmGrain);
      expect(updated.type, EffectType.filmGrain);
      expect(updated.intensity, 0.7); // 유지
    });

    test('copyWith - intensity만 변경', () {
      const config = EffectConfig(type: EffectType.neonGlow, intensity: 0.5);
      final updated = config.copyWith(intensity: 0.9);
      expect(updated.intensity, closeTo(0.9, 0.001));
      expect(updated.type, EffectType.neonGlow); // 유지
    });

    test('copyWith - type + intensity 동시 변경', () {
      const config = EffectConfig();
      final updated = config.copyWith(type: EffectType.bgBlur, intensity: 0.3);
      expect(updated.type, EffectType.bgBlur);
      expect(updated.intensity, closeTo(0.3, 0.001));
    });

    test('equality - 동일 type/intensity → 동등', () {
      const a = EffectConfig(type: EffectType.chromatic, intensity: 0.6);
      const b = EffectConfig(type: EffectType.chromatic, intensity: 0.6);
      expect(a, equals(b));
    });

    test('equality - 다른 type → 비동등', () {
      const a = EffectConfig(type: EffectType.neonGlow, intensity: 0.5);
      const b = EffectConfig(type: EffectType.filmNoir, intensity: 0.5);
      expect(a, isNot(equals(b)));
    });

    test('equality - 다른 intensity → 비동등', () {
      const a = EffectConfig(type: EffectType.filmGrain, intensity: 0.3);
      const b = EffectConfig(type: EffectType.filmGrain, intensity: 0.8);
      expect(a, isNot(equals(b)));
    });

    test('hashCode - 동일 값은 같은 해시', () {
      const a = EffectConfig(type: EffectType.bgBlur, intensity: 0.4);
      const b = EffectConfig(type: EffectType.bgBlur, intensity: 0.4);
      expect(a.hashCode, b.hashCode);
    });

    test('toString에 type name과 intensity 포함', () {
      const config = EffectConfig(type: EffectType.filmNoir, intensity: 0.75);
      final str = config.toString();
      expect(str, contains('filmNoir'));
      expect(str, contains('0.75'));
    });
  });
}
