import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../features/editor/editor_provider.dart';
import '../../widgets/before_after_slider.dart';
import 'export_provider.dart';

/// Phase 7 — Export 바텀 시트 화면
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(exportProvider.notifier).loadPreview();
    });
  }

  @override
  Widget build(BuildContext context) {
    final exportState = ref.watch(exportProvider);
    final editorState = ref.watch(editorProvider);

    // 성공/에러 메시지 스낵바 표시
    ref.listen<ExportState>(exportProvider, (prev, next) {
      if (next.successMessage != null && prev?.successMessage != next.successMessage) {
        _showSnackBar(next.successMessage!, isError: false);
        ref.read(exportProvider.notifier).clearMessages();
      }
      if (next.error != null && prev?.error != next.error) {
        _showSnackBar(next.error!, isError: true);
        ref.read(exportProvider.notifier).clearMessages();
      }
    });

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusXl)),
          ),
          child: Column(
            children: [
              _SheetHandle(),
              _Header(),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    children: [
                      // Before/After 미리보기
                      _PreviewSection(
                        exportState: exportState,
                        originalBytes: editorState.originalBytes,
                      ),

                      const SizedBox(height: AppSizes.lg),

                      // 액션 버튼들
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
                        child: Column(
                          children: [
                            _ActionButton(
                              icon: Icons.save_alt_rounded,
                              label: AppStrings.exportSavePhoto,
                              sublabel: AppStrings.exportSavePhotoSub,
                              isLoading: exportState.activeAction == ExportAction.savePhoto,
                              isEnabled: !exportState.isLoading,
                              gradient: AppColors.primaryGradient,
                              onTap: () => ref.read(exportProvider.notifier).saveToPhotos(),
                            ),
                            const SizedBox(height: AppSizes.sm),
                            _ActionButton(
                              icon: Icons.share_rounded,
                              label: AppStrings.exportShare,
                              sublabel: AppStrings.exportShareSub,
                              isLoading: exportState.activeAction == ExportAction.share,
                              isEnabled: !exportState.isLoading,
                              gradient: const LinearGradient(
                                colors: [AppColors.accentSecondary, AppColors.accent],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              onTap: () => ref.read(exportProvider.notifier).shareImage(),
                            ),
                            const SizedBox(height: AppSizes.sm),
                            _LoopVideoSection(exportState: exportState),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSizes.xl),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
      ),
    );
  }
}

// ── 상단 핸들 ────────────────────────────────────────────────────
class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.textTertiary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ── 헤더 ────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (bounds) =>
                AppColors.primaryGradient.createShader(bounds),
            child: const Text(
              AppStrings.exportTitle,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

// ── Before/After 미리보기 섹션 ────────────────────────────────────
class _PreviewSection extends StatelessWidget {
  final ExportState exportState;
  final Uint8List? originalBytes;

  const _PreviewSection({
    required this.exportState,
    required this.originalBytes,
  });

  @override
  Widget build(BuildContext context) {
    final editedFrame = exportState.previewFrame;
    final originalFrame = originalBytes;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      height: 280,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        child: _buildPreviewContent(editedFrame, originalFrame),
      ),
    );
  }

  Widget _buildPreviewContent(Uint8List? edited, Uint8List? original) {
    if (edited == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: AppSizes.sm),
            Text(
              AppStrings.exportRendering,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // 원본이 있으면 Before/After 슬라이더, 없으면 편집 결과만 표시
    if (original != null) {
      return BeforeAfterSlider(
        beforeImage: original,
        afterImage: edited,
      );
    }

    return Image.memory(edited, fit: BoxFit.contain);
  }
}

// ── 액션 버튼 ────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final bool isLoading;
  final bool isEnabled;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.isLoading,
    required this.isEnabled,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: isEnabled ? onTap : null,
        child: Container(
          height: AppSizes.actionButtonHeight,
          decoration: BoxDecoration(
            gradient: isEnabled ? gradient : null,
            color: isEnabled ? null : AppColors.card,
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          ),
          child: Row(
            children: [
              const SizedBox(width: AppSizes.md),
              isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      sublabel,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white60, size: 20),
              const SizedBox(width: AppSizes.sm),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Loop 영상 섹션 ───────────────────────────────────────────────
class _LoopVideoSection extends ConsumerWidget {
  final ExportState exportState;

  const _LoopVideoSection({required this.exportState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGenerating =
        exportState.activeAction == ExportAction.generateLoop ||
        exportState.activeAction == ExportAction.saveLoop;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  ),
                  child: const Text(
                    'LOOP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                const Expanded(
                  child: Text(
                    AppStrings.exportLoopTitle,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isGenerating)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSizes.md),
            child: Text(
              AppStrings.exportLoopDesc,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          const Divider(color: AppColors.divider, height: 1),
          Row(
            children: [
              Expanded(
                child: _LoopActionButton(
                  icon: Icons.share_rounded,
                  label: AppStrings.exportLoopShare,
                  isLoading: exportState.activeAction == ExportAction.generateLoop,
                  isEnabled: !exportState.isLoading,
                  onTap: () =>
                      ref.read(exportProvider.notifier).generateAndShareLoop(),
                ),
              ),
              Container(width: 1, height: 48, color: AppColors.divider),
              Expanded(
                child: _LoopActionButton(
                  icon: Icons.download_rounded,
                  label: AppStrings.exportLoopSave,
                  isLoading: exportState.activeAction == ExportAction.saveLoop,
                  isEnabled: !exportState.isLoading,
                  onTap: () =>
                      ref.read(exportProvider.notifier).saveLoopToPhotos(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoopActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isLoading;
  final bool isEnabled;
  final VoidCallback onTap;

  const _LoopActionButton({
    required this.icon,
    required this.label,
    required this.isLoading,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: SizedBox(
        height: 48,
        child: Opacity(
          opacity: isEnabled ? 1.0 : 0.4,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(icon, size: 18, color: AppColors.primaryLight),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.primaryLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
