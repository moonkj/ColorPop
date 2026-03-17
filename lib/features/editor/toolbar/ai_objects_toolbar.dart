import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../models/detected_object.dart';
import '../editor_provider.dart';

/// AI 감지 객체 칩 툴바
/// 감지된 객체 칩 목록 + "전체 선택" 칩을 가로 스크롤로 표시한다
class AiObjectsToolbar extends ConsumerWidget {
  const AiObjectsToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorProvider);

    if (state.isAiAnalyzing) {
      return _LoadingBar();
    }

    if (state.detectedObjects.isEmpty) {
      return _EmptyBar();
    }

    return Container(
      height: 72,
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppSizes.md,
              top: AppSizes.xs,
              bottom: AppSizes.xs,
            ),
            child: Text(
              AppStrings.aiObjects,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
              itemCount: state.detectedObjects.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSizes.sm),
              itemBuilder: (context, index) {
                final obj = state.detectedObjects[index];
                final isSelected = state.selectedObject == obj;
                return _ObjectChip(
                  object: obj,
                  isSelected: isSelected,
                  isLoading: state.isAiApplying && isSelected,
                  onTap: () => ref
                      .read(editorProvider.notifier)
                      .applyObjectMask(obj),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── 객체 칩 ────────────────────────────────────────────────────

class _ObjectChip extends StatelessWidget {
  final DetectedObject object;
  final bool isSelected;
  final bool isLoading;
  final VoidCallback onTap;

  const _ObjectChip({
    required this.object,
    required this.isSelected,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isSelected ? AppColors.primary : AppColors.card;
    final fgColor = isSelected ? Colors.white : AppColors.textSecondary;

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.xs,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          border: isSelected
              ? Border.all(color: AppColors.primaryLight, width: 1.5)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: fgColor,
                ),
              )
            else
              Icon(_iconForLabel(object.label), color: fgColor, size: 14),
            const SizedBox(width: AppSizes.xs),
            Text(
              object.korLabel,
              style: TextStyle(
                color: fgColor,
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForLabel(String label) {
    switch (label) {
      case 'person':
        return Icons.person_outline;
      case 'face':
        return Icons.face_outlined;
      case 'sky':
        return Icons.wb_sunny_outlined;
      case 'nonSubject':
        return Icons.layers_outlined;
      default:
        return Icons.pets_outlined;
    }
  }
}

// ── 로딩 바 ────────────────────────────────────────────────────

class _LoadingBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      color: AppColors.surface,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Text(
              AppStrings.aiAnalyzing,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 빈 상태 바 ─────────────────────────────────────────────────

class _EmptyBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      color: AppColors.surface,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppStrings.aiNoObjects,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            AppStrings.aiNoObjectsSubtitle,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
