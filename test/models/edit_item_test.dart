import 'package:flutter_test/flutter_test.dart';
import 'package:color_pop/models/edit_item.dart';

void main() {
  group('EditItem', () {
    test('toJson / fromJson 왕복 직렬화', () {
      final original = EditItem(
        id: '12345',
        imagePath: '/path/to/image.jpg',
        createdAt: DateTime(2026, 3, 17, 12, 0),
        editedAt: DateTime(2026, 3, 17, 13, 0),
      );

      final json = original.toJson();
      final restored = EditItem.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.imagePath, original.imagePath);
      expect(restored.createdAt, original.createdAt);
      expect(restored.editedAt, original.editedAt);
    });

    test('editedAt 없을 때 fromJson 정상 처리', () {
      final item = EditItem(
        id: '1',
        imagePath: '/test.jpg',
        createdAt: DateTime(2026, 1, 1),
      );
      final json = item.toJson();
      final restored = EditItem.fromJson(json);
      expect(restored.editedAt, isNull);
    });

    test('relativeTime - 방금 전 (1분 미만)', () {
      final item = EditItem(
        id: '1',
        imagePath: '/test.jpg',
        createdAt: DateTime.now().subtract(const Duration(seconds: 30)),
      );
      expect(item.relativeTime, '방금 전');
    });

    test('relativeTime - N분 전', () {
      final item = EditItem(
        id: '1',
        imagePath: '/test.jpg',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      expect(item.relativeTime, '5분 전');
    });

    test('relativeTime - N시간 전', () {
      final item = EditItem(
        id: '1',
        imagePath: '/test.jpg',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      );
      expect(item.relativeTime, '3시간 전');
    });

    test('relativeTime - N일 전', () {
      final item = EditItem(
        id: '1',
        imagePath: '/test.jpg',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      );
      expect(item.relativeTime, '2일 전');
    });

    test('relativeTime - editedAt 우선 사용', () {
      final item = EditItem(
        id: '1',
        imagePath: '/test.jpg',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        editedAt: DateTime.now().subtract(const Duration(minutes: 2)),
      );
      // editedAt이 최근이므로 "2분 전" 이어야 함
      expect(item.relativeTime, '2분 전');
    });

    test('copyWith - 특정 필드만 변경', () {
      final original = EditItem(
        id: '1',
        imagePath: '/old.jpg',
        createdAt: DateTime(2026, 1, 1),
      );
      final updated = original.copyWith(imagePath: '/new.jpg');
      expect(updated.imagePath, '/new.jpg');
      expect(updated.id, '1');
      expect(updated.createdAt, DateTime(2026, 1, 1));
    });
  });
}
