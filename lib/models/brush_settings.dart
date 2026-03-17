enum BrushMode { reveal, erase }

class BrushSettings {
  final double size;       // 5 ~ 150 px (이미지 공간 기준)
  final double softness;   // 0.0 (딱딱) ~ 1.0 (매우 부드러움)
  final double opacity;    // 0.1 ~ 1.0
  final BrushMode mode;

  const BrushSettings({
    this.size = 40.0,
    this.softness = 0.5,
    this.opacity = 1.0,
    this.mode = BrushMode.reveal,
  });

  BrushSettings copyWith({
    double? size,
    double? softness,
    double? opacity,
    BrushMode? mode,
  }) {
    return BrushSettings(
      size: size ?? this.size,
      softness: softness ?? this.softness,
      opacity: opacity ?? this.opacity,
      mode: mode ?? this.mode,
    );
  }

  // 네이티브 채널로 전달할 Map
  Map<String, dynamic> toMap() => {
        'size': size,
        'softness': softness,
        'opacity': opacity,
        'isReveal': mode == BrushMode.reveal,
      };
}
