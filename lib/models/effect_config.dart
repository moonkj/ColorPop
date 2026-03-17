enum EffectType { none, neonGlow, chromatic, filmGrain, bgBlur, filmNoir }

class EffectConfig {
  final EffectType type;
  final double intensity; // 0.0~1.0

  const EffectConfig({
    this.type = EffectType.none,
    this.intensity = 0.5,
  });

  EffectConfig copyWith({EffectType? type, double? intensity}) {
    return EffectConfig(
      type: type ?? this.type,
      intensity: intensity ?? this.intensity,
    );
  }

  /// Native 채널 전달용 String
  String get typeString => type.name;

  @override
  bool operator ==(Object other) =>
      other is EffectConfig && other.type == type && other.intensity == intensity;

  @override
  int get hashCode => Object.hash(type, intensity);

  @override
  String toString() => 'EffectConfig(type=${type.name}, intensity=${intensity.toStringAsFixed(2)})';
}
