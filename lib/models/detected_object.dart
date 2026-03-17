/// Vision 프레임워크에서 감지된 객체
class DetectedObject {
  final String label;       // 영문 식별자 ("person", "face", "sky" ...)
  final String korLabel;    // 한국어 레이블
  final double confidence;  // 신뢰도 (0~1)
  final double x, y, w, h; // 정규화 좌표 (Vision 좌표계)
  final String maskType;    // "person" | "boundingBox" | "topRegion" | "inverted"

  const DetectedObject({
    required this.label,
    required this.korLabel,
    required this.confidence,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.maskType,
  });

  factory DetectedObject.fromMap(Map<String, dynamic> map) {
    return DetectedObject(
      label: map['label'] as String,
      korLabel: map['korLabel'] as String,
      confidence: (map['confidence'] as num).toDouble(),
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      w: (map['w'] as num).toDouble(),
      h: (map['h'] as num).toDouble(),
      maskType: map['maskType'] as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'label': label,
        'korLabel': korLabel,
        'confidence': confidence,
        'x': x,
        'y': y,
        'w': w,
        'h': h,
        'maskType': maskType,
      };

  @override
  bool operator ==(Object other) =>
      other is DetectedObject && other.label == label;

  @override
  int get hashCode => label.hashCode;

  @override
  String toString() => 'DetectedObject($label, $korLabel, conf=${confidence.toStringAsFixed(2)})';
}
