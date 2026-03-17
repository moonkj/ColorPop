import 'package:flutter/material.dart';

/// 이미지 탭으로 샘플링한 색상 정보
class ColorSelection {
  final double h;           // Hue 0~1
  final double s;           // Saturation 0~1
  final double l;           // Lightness 0~1
  final String hexColor;    // "#RRGGBB"
  final double tolerance;   // Hue 허용 범위 0.0~0.5 (기본 0.1 ≈ ±36°)
  final bool isRangeMode;   // 그라디언트 범위 모드 (B-6)
  final double? rangeEndH;  // 범위 끝 Hue (rangeMode일 때만 사용)

  const ColorSelection({
    required this.h,
    required this.s,
    required this.l,
    required this.hexColor,
    this.tolerance = 0.10,
    this.isRangeMode = false,
    this.rangeEndH,
  });

  factory ColorSelection.fromMap(Map<String, dynamic> map) {
    return ColorSelection(
      h: (map['h'] as num).toDouble(),
      s: (map['s'] as num).toDouble(),
      l: (map['l'] as num).toDouble(),
      hexColor: map['hexColor'] as String,
    );
  }

  ColorSelection copyWith({
    double? tolerance,
    bool? isRangeMode,
    double? rangeEndH,
    bool clearRangeEnd = false,
  }) {
    return ColorSelection(
      h: h,
      s: s,
      l: l,
      hexColor: hexColor,
      tolerance: tolerance ?? this.tolerance,
      isRangeMode: isRangeMode ?? this.isRangeMode,
      rangeEndH: clearRangeEnd ? null : (rangeEndH ?? this.rangeEndH),
    );
  }

  /// hexColor → Flutter Color
  Color get color {
    final hex = hexColor.replaceFirst('#', '');
    if (hex.length != 6) return Colors.white;
    final value = int.tryParse('FF$hex', radix: 16);
    return value != null ? Color(value) : Colors.white;
  }

  /// tolerance를 0~100 퍼센트 슬라이더 값으로 변환
  double get tolerancePercent => (tolerance / 0.5) * 100.0;

  /// 0~100 슬라이더 값 → tolerance (0~0.5)
  static double toleranceFromPercent(double percent) => (percent / 100.0) * 0.5;

  @override
  bool operator ==(Object other) =>
      other is ColorSelection &&
      other.h == h &&
      other.s == s &&
      other.hexColor == hexColor;

  @override
  int get hashCode => Object.hash(h, s, hexColor);

  @override
  String toString() =>
      'ColorSelection(hex=$hexColor, H=${h.toStringAsFixed(2)}, tol=${tolerance.toStringAsFixed(2)})';
}
