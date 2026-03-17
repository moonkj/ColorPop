import 'package:flutter/material.dart';

/// AI 팔레트 추천 단일 항목
class AiSuggestion {
  final String id;          // 고유 식별자
  final String title;       // 추천 제목 (한국어)
  final String description; // 설명 (한국어)
  final String maskLabel;   // 적용할 마스크 레이블
  final String colorHex;    // 대표 색상 (#RRGGBB)

  const AiSuggestion({
    required this.id,
    required this.title,
    required this.description,
    required this.maskLabel,
    required this.colorHex,
  });

  factory AiSuggestion.fromMap(Map<String, dynamic> map) {
    return AiSuggestion(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      maskLabel: map['maskLabel'] as String,
      colorHex: map['colorHex'] as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'maskLabel': maskLabel,
        'colorHex': colorHex,
      };

  /// colorHex(#RRGGBB)를 Flutter Color로 변환
  Color get color {
    final hex = colorHex.replaceFirst('#', '');
    if (hex.length != 6) return Colors.white;
    final value = int.tryParse('FF$hex', radix: 16);
    return value != null ? Color(value) : Colors.white;
  }

  @override
  bool operator ==(Object other) =>
      other is AiSuggestion && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AiSuggestion($id, $title)';
}
