import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../models/ai_suggestion.dart';
import '../editor_provider.dart';

/// AI 추천 패널
/// Smart Palette가 제안하는 최대 3개의 추천 카드를 가로 스크롤로 표시한다
class AiSuggestionPanel extends ConsumerWidget {
  const AiSuggestionPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestions = ref.watch(
      editorProvider.select((s) => s.aiSuggestions),
    );
    final isApplying = ref.watch(
      editorProvider.select((s) => s.isAiApplying),
    );

    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSizes.md,
            bottom: AppSizes.xs,
          ),
          child: Text(
            AppStrings.aiSuggestions,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
            itemCount: suggestions.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSizes.sm),
            itemBuilder: (context, index) {
              final suggestion = suggestions[index];
              return _SuggestionCard(
                suggestion: suggestion,
                isLoading: isApplying,
                onTap: () => ref
                    .read(editorProvider.notifier)
                    .applySuggestion(suggestion),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── 추천 카드 ───────────────────────────────────────────────────

class _SuggestionCard extends StatelessWidget {
  final AiSuggestion suggestion;
  final bool isLoading;
  final VoidCallback onTap;

  const _SuggestionCard({
    required this.suggestion,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = suggestion.color;

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(AppSizes.sm),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(
            color: accent.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // 색상 도트
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    suggestion.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    suggestion.description,
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.only(left: AppSizes.xs),
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
