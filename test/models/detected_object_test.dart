import 'package:flutter_test/flutter_test.dart';
import 'package:color_pop/models/detected_object.dart';

void main() {
  group('DetectedObject', () {
    const person = DetectedObject(
      label: 'person',
      korLabel: '인물',
      confidence: 0.98,
      x: 0.1, y: 0.2, w: 0.4, h: 0.6,
      maskType: 'person',
    );

    test('fromMap - 모든 필드가 올바르게 파싱된다', () {
      final map = {
        'label': 'person',
        'korLabel': '인물',
        'confidence': 0.98,
        'x': 0.1, 'y': 0.2, 'w': 0.4, 'h': 0.6,
        'maskType': 'person',
      };
      final obj = DetectedObject.fromMap(map);
      expect(obj.label, 'person');
      expect(obj.korLabel, '인물');
      expect(obj.confidence, closeTo(0.98, 0.001));
      expect(obj.maskType, 'person');
    });

    test('toMap - 직렬화 후 복원이 동일하다', () {
      final map = person.toMap();
      final restored = DetectedObject.fromMap(map);
      expect(restored.label, person.label);
      expect(restored.korLabel, person.korLabel);
      expect(restored.confidence, person.confidence);
      expect(restored.x, person.x);
      expect(restored.y, person.y);
      expect(restored.w, person.w);
      expect(restored.h, person.h);
    });

    test('동일한 label을 가진 두 객체는 동등하다', () {
      const person2 = DetectedObject(
        label: 'person', korLabel: '인물', confidence: 0.5,
        x: 0, y: 0, w: 1, h: 1, maskType: 'person',
      );
      expect(person, equals(person2));
    });

    test('다른 label은 동등하지 않다', () {
      const face = DetectedObject(
        label: 'face', korLabel: '얼굴', confidence: 0.9,
        x: 0.2, y: 0.3, w: 0.2, h: 0.2, maskType: 'boundingBox',
      );
      expect(person, isNot(equals(face)));
    });

    test('fromMap - 정수형 confidence도 double로 변환된다', () {
      final map = {
        'label': 'sky', 'korLabel': '하늘', 'confidence': 1,
        'x': 0.0, 'y': 0.6, 'w': 1.0, 'h': 0.4, 'maskType': 'topRegion',
      };
      final obj = DetectedObject.fromMap(map);
      expect(obj.confidence, 1.0);
      expect(obj.confidence, isA<double>());
    });

    test('nonSubject 칩 생성 확인', () {
      const nonSubject = DetectedObject(
        label: 'nonSubject',
        korLabel: '배경 전체',
        confidence: 1.0,
        x: 0, y: 0, w: 1, h: 1,
        maskType: 'inverted',
      );
      expect(nonSubject.maskType, 'inverted');
      expect(nonSubject.korLabel, '배경 전체');
    });

    test('toString에 label과 korLabel이 포함된다', () {
      final str = person.toString();
      expect(str, contains('person'));
      expect(str, contains('인물'));
    });
  });
}
