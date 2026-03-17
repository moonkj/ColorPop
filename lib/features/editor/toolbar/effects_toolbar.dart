import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../models/effect_config.dart';
import '../editor_provider.dart';

/// Phase 5 이펙트 툴바
/// 이펙트 칩 + 강도 슬라이더 + 반전 모드 토글
class EffectsToolbar extends ConsumerWidget {
  const EffectsToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorProvider);
    final notifier = ref.read(editorProvider.notifier);
    final config = state.effectConfig;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 이펙트 칩 + 반전 모드 ───────────────────────────────
          SizedBox(
            height: 40,
            child: Row(
              children: [
                Expanded(
                  child: _EffectChipRow(
                    current: config.type,
                    onSelect: (t) => notifier.setEffectType(t),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                _InverseToggle(
                  isActive: state.isInverseMode,
                  onTap: () => notifier.toggleInverseMode(),
                ),
              ],
            ),
          ),

          // ── 강도 슬라이더 (이펙트 선택 시만 표시) ──────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: config.type != EffectType.none
                ? _IntensitySlider(
                    intensity: config.intensity,
                    onChanged: (v) => notifier.updateEffectIntensity(v),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── 이펙트 칩 목록 ──────────────────────────────────────────────
class _EffectChipRow extends StatelessWidget {
  final EffectType current;
  final ValueChanged<EffectType> onSelect;

  const _EffectChipRow({required this.current, required this.onSelect});

  static const _chips = <(EffectType, String, IconData)>[
    (EffectType.none,      AppStrings.effectNone,      Icons.do_not_disturb_alt_outlined),
    (EffectType.neonGlow,  AppStrings.effectNeonGlow,  Icons.auto_awesome_outlined),
    (EffectType.chromatic, AppStrings.effectChromatic, Icons.blur_on_outlined),
    (EffectType.filmGrain, AppStrings.effectFilmGrain, Icons.grain_outlined),
    (EffectType.bgBlur,    AppStrings.effectBgBlur,    Icons.deblur_outlined),
    (EffectType.filmNoir,  AppStrings.effectFilmNoir,  Icons.movie_filter_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _chips.length,
      separatorBuilder: (_, __) => const SizedBox(width: AppSizes.xs),
      itemBuilder: (_, i) {
        final (type, label, icon) = _chips[i];
        final isSelected = current == type;
        return _EffectChip(
          label: label,
          icon: icon,
          isSelected: isSelected,
          onTap: () => onSelect(type),
        );
      },
    );
  }
}

class _EffectChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _EffectChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.sm,
          vertical: AppSizes.xs,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          border: isSelected
              ? null
              : Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 반전 모드 토글 ──────────────────────────────────────────────
class _InverseToggle extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _InverseToggle({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.sm,
          vertical: AppSizes.xs,
        ),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryLight : AppColors.card,
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          border: isActive
              ? null
              : Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.swap_horiz_rounded,
              size: 13,
              color: isActive ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              AppStrings.effectInverseMode,
              style: TextStyle(
                color: isActive ? Colors.white : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 강도 슬라이더 ───────────────────────────────────────────────
class _IntensitySlider extends StatelessWidget {
  final double intensity;
  final ValueChanged<double> onChanged;

  const _IntensitySlider({required this.intensity, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.xs),
      child: Row(
        children: [
          Text(
            AppStrings.effectIntensity,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: AppColors.divider,
                thumbColor: AppColors.primaryLight,
                overlayColor: AppColors.primary.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: intensity.clamp(0.0, 1.0),
                min: 0,
                max: 1,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '${(intensity * 100).round()}%',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
