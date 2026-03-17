import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// Before(원본) / After(편집) 비교 슬라이더 위젯
/// 드래그로 경계선 위치를 조절하여 두 이미지를 비교한다
class BeforeAfterSlider extends StatefulWidget {
  /// 원본 이미지 바이트
  final Uint8List beforeImage;

  /// 편집 완료 이미지 바이트
  final Uint8List afterImage;

  const BeforeAfterSlider({
    super.key,
    required this.beforeImage,
    required this.afterImage,
  });

  @override
  State<BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<BeforeAfterSlider> {
  double _splitFraction = 0.5; // 0.0 = 전체 before, 1.0 = 전체 after

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width  = constraints.maxWidth;
        final height = constraints.maxHeight;

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              _splitFraction =
                  (_splitFraction + details.delta.dx / width).clamp(0.02, 0.98);
            });
          },
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Before (원본) — 전체 표시
                Image.memory(
                  widget.beforeImage,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),

                // After (편집) — 왼쪽 절반만 표시
                Align(
                  alignment: Alignment.centerLeft,
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: _splitFraction,
                      child: Image.memory(
                        widget.afterImage,
                        fit: BoxFit.contain,
                        width: width,
                        height: height,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                ),

                // 구분선
                Positioned(
                  left: width * _splitFraction - 1,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 2,
                    color: Colors.white,
                  ),
                ),

                // 드래그 핸들
                Positioned(
                  left: width * _splitFraction - 20,
                  top: height / 2 - 20,
                  child: _DragHandle(),
                ),

                // Before / After 레이블
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: _Label(text: 'BEFORE'),
                ),
                Positioned(
                  left: width * _splitFraction + 8,
                  bottom: 12,
                  child: Opacity(
                    opacity: _splitFraction < 0.9 ? 1.0 : 0.0,
                    child: _Label(text: 'AFTER'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.compare_arrows,
        color: AppColors.background,
        size: 20,
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
