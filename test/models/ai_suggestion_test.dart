import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:color_pop/models/ai_suggestion.dart';

void main() {
  group('AiSuggestion', () {
    const personSuggestion = AiSuggestion(
      id: 'suggest_person',
      title: '인물 컬러 살리기',
      description: 'AI가 감지한 인물만 선명한 컬러로',
      maskLabel: 'person',
      colorHex: '#FF6B9D',
    );

    test('fromMap - 모든 필드가 올바르게 파싱된다', () {
      final map = {
        'id': 'suggest_person',
        'title': '인물 컬러 살리기',
        'description': 'AI가 감지한 인물만 선명한 컬러로',
        'maskLabel': 'person',
        'colorHex': '#FF6B9D',
      };
      final s = AiSuggestion.fromMap(map);
      expect(s.id, 'suggest_person');
      expect(s.title, '인물 컬러 살리기');
      expect(s.maskLabel, 'person');
      expect(s.colorHex, '#FF6B9D');
    });

    test('toMap - 직렬화 후 복원이 동일하다', () {
      final map = personSuggestion.toMap();
      final restored = AiSuggestion.fromMap(map);
      expect(restored.id, personSuggestion.id);
      expect(restored.title, personSuggestion.title);
      expect(restored.maskLabel, personSuggestion.maskLabel);
    });

    test('color - #FF6B9D를 올바른 Color로 변환한다', () {
      final color = personSuggestion.color;
      expect(color.red, 0xFF);
      expect(color.green, 0x6B);
      expect(color.blue, 0x9D);
    });

    test('color - #87CEEB (하늘색) 변환', () {
      const sky = AiSuggestion(
        id: 'suggest_sky',
        title: '하늘빛 살리기',
        description: '파란 하늘만 컬러로',
        maskLabel: 'sky',
        colorHex: '#87CEEB',
      );
      final color = sky.color;
      expect(color.red, 0x87);
      expect(color.green, 0xCE);
      expect(color.blue, 0xEB);
    });

    test('color - 잘못된 hex는 white를 반환한다', () {
      const bad = AiSuggestion(
        id: 'bad',
        title: 'bad',
        description: 'bad',
        maskLabel: 'bad',
        colorHex: 'invalid',
      );
      expect(bad.color, equals(Colors.white));
    });

    test('동일 id를 가진 두 제안은 동등하다', () {
      const copy = AiSuggestion(
        id: 'suggest_person',
        title: '다른 제목',
        description: '다른 설명',
        maskLabel: 'person',
        colorHex: '#000000',
      );
      expect(personSuggestion, equals(copy));
    });

    test('다른 id는 동등하지 않다', () {
      const sky = AiSuggestion(
        id: 'suggest_sky',
        title: '하늘빛 살리기',
        description: '파란 하늘만 컬러로',
        maskLabel: 'sky',
        colorHex: '#87CEEB',
      );
      expect(personSuggestion, isNot(equals(sky)));
    });

    test('toString에 id와 title이 포함된다', () {
      final str = personSuggestion.toString();
      expect(str, contains('suggest_person'));
      expect(str, contains('인물 컬러 살리기'));
    });
  });
}
