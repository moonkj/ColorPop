import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../editor_provider.dart';

/// Selective Color 툴바
/// 선택된 색상 미리보기 + Tolerance 슬라이더 + 그라디언트 범위 모드 토글
class ColorPickerToolbar extends ConsumerWidget {
  const ColorPickerToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorProvider);
    final sel = state.colorSelection;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      child: sel == null
          ? _TapHintBar(isRangeMode: state.isColorRangeMode)
          : _ActiveBar(
              isApplying: state.isColorApplying,
              isRangeMode: state.isColorRangeMode,
              onRangeModeToggle: () =>
                  ref.read(editorProvider.notifier).toggleColorRangeMode(),
              tolerancePercent: sel.tolerancePercent,
              onToleranceChanged: (v) =>
                  ref.read(editorProvider.notifier).updateColorTolerance(v),
              selectedColor: sel.color,
              rangeEndColor: state.colorRangeEndSelection?.color,
            ),
    );
  }
}

// ── 색상 미선택 상태 ─────────────────────────────────────────────

class _TapHintBar extends StatelessWidget {
  final bool isRangeMode;
  const _TapHintBar({required this.isRangeMode});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          const Icon(Icons.colorize, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: AppSizes.sm),
          Text(
            isRangeMode
                ? AppStrings.colorRangeSecondTap
                : AppStrings.colorTapHint,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 색상 선택 완료 상태 ──────────────────────────────────────────

class _ActiveBar extends StatelessWidget {
  final bool isApplying;
  final bool isRangeMode;
  final VoidCallback onRangeModeToggle;
  final double tolerancePercent;
  final ValueChanged<double> onToleranceChanged;
  final Color selectedColor;
  final Color? rangeEndColor;

  const _ActiveBar({
    required this.isApplying,
    required this.isRangeMode,
    required this.onRangeModeToggle,
    required this.tolerancePercent,
    required this.onToleranceChanged,
    required this.selectedColor,
    this.rangeEndColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 색상 미리보기 행
        SizedBox(
          height: 40,
          child: Row(
            children: [
              // 선택된 색상 원
              _ColorDot(color: selectedColor, size: 30),

              // 그라디언트 범위 모드: 화살표 + 끝 색상 원
              if (isRangeMode) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSizes.sm),
                  child: Icon(Icons.arrow_forward,
                      color: AppColors.textTertiary, size: 16),
                ),
                _ColorDot(
                  color: rangeEndColor ?? Colors.transparent,
                  size: 30,
                  isPlaceholder: rangeEndColor == null,
                ),
              ],

              const Spacer(),

              // 그라디언트 범위 모드 토글
              GestureDetector(
                onTap: onRangeModeToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.sm,
                    vertical: AppSizes.xs,
                  ),
                  decoration: BoxDecoration(
                    color: isRangeMode
                        ? AppColors.primary
                        : AppColors.card,
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusFull),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.gradient,
                        color: isRangeMode
                            ? Colors.white
                            : AppColors.textSecondary,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        AppStrings.colorRangeMode,
                        style: TextStyle(
                          color: isRangeMode
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (isApplying) ...[
                const SizedBox(width: AppSizes.sm),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: AppSizes.xs),

        // Tolerance 슬라이더
        Row(
          children: [
            Text(
              AppStrings.colorTolerance,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 7),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: AppColors.divider,
                  thumbColor: AppColors.primaryLight,
                  overlayColor:
                      AppColors.primary.withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: tolerancePercent.clamp(0.0, 100.0),
                  min: 0,
                  max: 100,
                  onChanged: isApplying ? null : onToleranceChanged,
                ),
              ),
            ),
            SizedBox(
              width: 36,
              child: Text(
                '${tolerancePercent.round()}%',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── 색상 원 컴포넌트 ────────────────────────────────────────────

class _ColorDot extends StatelessWidget {
  final Color color;
  final double size;
  final bool isPlaceholder;

  const _ColorDot({
    required this.color,
    required this.size,
    this.isPlaceholder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isPlaceholder ? Colors.transparent : color,
        border: Border.all(
          color: isPlaceholder
              ? AppColors.textTertiary
              : color.withValues(alpha: 0.3),
          width: isPlaceholder ? 1.5 : 2,
        ),
        boxShadow: isPlaceholder
            ? null
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
      ),
      child: isPlaceholder
          ? const Icon(Icons.add, color: AppColors.textTertiary, size: 14)
          : null,
    );
  }
}
