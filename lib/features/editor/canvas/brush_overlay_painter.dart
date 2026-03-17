import 'package:flutter/material.dart';
import '../../../models/brush_settings.dart';

/// 브러시 획을 화면에 즉각 표시하는 CustomPainter
/// 네이티브 렌더링보다 먼저 보여줘 사용자에게 즉각적인 피드백 제공
class BrushOverlayPainter extends CustomPainter {
  final List<Offset> points;         // 현재 획의 좌표 목록 (이미지 공간)
  final BrushSettings settings;
  final Size imageDisplaySize;       // 화면에서 이미지가 실제 표시되는 크기
  final Offset imageDisplayOffset;   // 이미지 표시 시작 오프셋 (letterbox 보정)

  const BrushOverlayPainter({
    required this.points,
    required this.settings,
    required this.imageDisplaySize,
    required this.imageDisplayOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final color = settings.mode == BrushMode.reveal
        ? Colors.white.withValues(alpha: settings.opacity * 0.6)
        : Colors.red.withValues(alpha: settings.opacity * 0.5);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        settings.size * settings.softness * 0.5,
      );

    for (final point in points) {
      // 정규화 좌표(0-1) → 화면 좌표 변환
      final screenX = imageDisplayOffset.dx + point.dx * imageDisplaySize.width;
      final screenY = imageDisplayOffset.dy + point.dy * imageDisplaySize.height;
      final radius = settings.size * 0.5 *
          (imageDisplaySize.width / (imageDisplaySize.width > 0 ? imageDisplaySize.width : 1));

      canvas.drawCircle(Offset(screenX, screenY), radius, paint);
    }
  }

  @override
  bool shouldRepaint(BrushOverlayPainter old) =>
      old.points.length != points.length || old.settings != settings;
}

/// 브러시 커서 (현재 손가락 위치 표시)
class BrushCursorPainter extends CustomPainter {
  final Offset? position;           // 화면 좌표
  final double radius;
  final BrushMode mode;

  const BrushCursorPainter({
    required this.position,
    required this.radius,
    required this.mode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (position == null) return;

    final color =
        mode == BrushMode.reveal ? Colors.white : Colors.redAccent;

    // 외곽선 원
    canvas.drawCircle(
      position!,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // 중심점
    canvas.drawCircle(
      position!,
      2,
      Paint()
        ..color = color.withValues(alpha: 0.8)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(BrushCursorPainter old) =>
      old.position != position || old.radius != radius;
}
