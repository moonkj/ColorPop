import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:color_pop/models/color_selection.dart';

void main() {
  group('ColorSelection', () {
    const redSel = ColorSelection(
      h: 0.0, s: 1.0, l: 0.5,
      hexColor: '#FF0000',
      tolerance: 0.10,
    );

    // ── fromMap ───────────────────────────────────────────────
    group('fromMap', () {
      test('정상 맵에서 생성', () {
        final sel = ColorSelection.fromMap({
          'h': 0.33, 's': 0.8, 'l': 0.5, 'hexColor': '#44FF00',
        });
        expect(sel.h, closeTo(0.33, 0.001));
        expect(sel.s, closeTo(0.8, 0.001));
        expect(sel.l, closeTo(0.5, 0.001));
        expect(sel.hexColor, '#44FF00');
        expect(sel.tolerance, 0.10); // 기본값
      });

      test('int 타입 num 처리', () {
        final sel = ColorSelection.fromMap({
          'h': 0, 's': 1, 'l': 0, 'hexColor': '#000000',
        });
        expect(sel.h, 0.0);
        expect(sel.s, 1.0);
      });
    });

    // ── color getter ──────────────────────────────────────────
    group('color getter', () {
      test('#FF0000 → 빨간색', () {
        expect(redSel.color, const Color(0xFFFF0000));
      });

      test('#0000FF → 파란색', () {
        const sel = ColorSelection(h: 0.67, s: 1.0, l: 0.5, hexColor: '#0000FF');
        expect(sel.color, const Color(0xFF0000FF));
      });

      test('잘못된 hexColor → Colors.white', () {
        const sel = ColorSelection(h: 0.0, s: 0.0, l: 0.5, hexColor: 'INVALID');
        expect(sel.color, Colors.white);
      });
    });

    // ── tolerancePercent / toleranceFromPercent ───────────────
    group('tolerancePercent', () {
      test('0.10 tolerance → 20%', () {
        expect(redSel.tolerancePercent, closeTo(20.0, 0.001));
      });

      test('0.25 tolerance → 50%', () {
        final sel = redSel.copyWith(tolerance: 0.25);
        expect(sel.tolerancePercent, closeTo(50.0, 0.001));
      });

      test('0.5 tolerance (최대) → 100%', () {
        final sel = redSel.copyWith(tolerance: 0.5);
        expect(sel.tolerancePercent, closeTo(100.0, 0.001));
      });
    });

    group('toleranceFromPercent', () {
      test('0% → 0.0', () {
        expect(ColorSelection.toleranceFromPercent(0), closeTo(0.0, 0.001));
      });

      test('50% → 0.25', () {
        expect(ColorSelection.toleranceFromPercent(50), closeTo(0.25, 0.001));
      });

      test('100% → 0.5', () {
        expect(ColorSelection.toleranceFromPercent(100), closeTo(0.5, 0.001));
      });

      test('왕복 일관성: percent → tolerance → percent', () {
        for (final p in [0.0, 20.0, 50.0, 75.0, 100.0]) {
          final tol = ColorSelection.toleranceFromPercent(p);
          final back = (tol / 0.5) * 100.0;
          expect(back, closeTo(p, 0.001));
        }
      });
    });

    // ── copyWith ──────────────────────────────────────────────
    group('copyWith', () {
      test('tolerance 변경 — h/s/l/hexColor 유지', () {
        final updated = redSel.copyWith(tolerance: 0.2);
        expect(updated.tolerance, 0.2);
        expect(updated.h, redSel.h);
        expect(updated.hexColor, redSel.hexColor);
      });

      test('rangeEndH 설정', () {
        final updated = redSel.copyWith(rangeEndH: 0.6);
        expect(updated.rangeEndH, closeTo(0.6, 0.001));
      });

      test('clearRangeEnd=true → rangeEndH null', () {
        final withRange = redSel.copyWith(rangeEndH: 0.6);
        final cleared = withRange.copyWith(clearRangeEnd: true);
        expect(cleared.rangeEndH, isNull);
      });

      test('clearRangeEnd=false → rangeEndH 유지', () {
        final withRange = redSel.copyWith(rangeEndH: 0.6);
        final unchanged = withRange.copyWith(tolerance: 0.3);
        expect(unchanged.rangeEndH, closeTo(0.6, 0.001));
      });
    });

    // ── equality ─────────────────────────────────────────────
    group('equality', () {
      test('동일 h/s/hexColor → 동등', () {
        const a = ColorSelection(h: 0.0, s: 1.0, l: 0.5, hexColor: '#FF0000');
        const b = ColorSelection(h: 0.0, s: 1.0, l: 0.3, hexColor: '#FF0000', tolerance: 0.2);
        expect(a, equals(b)); // l과 tolerance는 equality에서 제외
      });

      test('다른 h → 비동등', () {
        const a = ColorSelection(h: 0.0, s: 1.0, l: 0.5, hexColor: '#FF0000');
        const b = ColorSelection(h: 0.5, s: 1.0, l: 0.5, hexColor: '#FF0000');
        expect(a, isNot(equals(b)));
      });
    });

    // ── toString ─────────────────────────────────────────────
    test('toString에 hexColor와 H 포함', () {
      final str = redSel.toString();
      expect(str, contains('#FF0000'));
      expect(str, contains('H='));
    });
  });
}
