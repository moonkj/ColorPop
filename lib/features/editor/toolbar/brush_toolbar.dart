import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../models/brush_settings.dart';
import '../editor_provider.dart';

class BrushToolbar extends ConsumerWidget {
  const BrushToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(editorProvider).brushSettings;
    final notifier = ref.read(editorProvider.notifier);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSizes.md, AppSizes.sm, AppSizes.md, AppSizes.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 슬라이더: 브러시 크기 ────────────────────────────
          _SliderRow(
            label: '크기',
            value: settings.size,
            min: 5,
            max: 150,
            displayValue: '${settings.size.round()}',
            onChanged: (v) =>
                notifier.updateBrushSettings(settings.copyWith(size: v)),
          ),
          const SizedBox(height: AppSizes.xs),

          // ── 슬라이더: 부드러움 ──────────────────────────────
          _SliderRow(
            label: '부드러움',
            value: settings.softness,
            min: 0,
            max: 1,
            displayValue: '${(settings.softness * 100).round()}%',
            onChanged: (v) =>
                notifier.updateBrushSettings(settings.copyWith(softness: v)),
          ),
          const SizedBox(height: AppSizes.sm),

          // ── 모드 토글: Reveal / Erase ───────────────────────
          Row(
            children: [
              Expanded(
                child: _ModeButton(
                  label: '컬러 살리기',
                  icon: Icons.brush,
                  isSelected: settings.mode == BrushMode.reveal,
                  selectedColor: AppColors.primary,
                  onTap: () => notifier.updateBrushSettings(
                    settings.copyWith(mode: BrushMode.reveal),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: _ModeButton(
                  label: '흑백으로',
                  icon: Icons.auto_fix_normal,
                  isSelected: settings.mode == BrushMode.erase,
                  selectedColor: AppColors.error,
                  onTap: () => notifier.updateBrushSettings(
                    settings.copyWith(mode: BrushMode.erase),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 슬라이더 행 ────────────────────────────────────────────────
class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String displayValue;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.displayValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            displayValue,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

// ── 모드 버튼 ─────────────────────────────────────────────────
class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 40,
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor.withValues(alpha: 0.15)
              : AppColors.card,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(
            color: isSelected ? selectedColor : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: isSelected ? selectedColor : AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? selectedColor : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
