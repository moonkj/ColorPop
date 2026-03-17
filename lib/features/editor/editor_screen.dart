import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../models/edit_item.dart';
import '../../features/export/export_screen.dart';
import 'canvas/editor_canvas.dart';
import 'toolbar/brush_toolbar.dart';
import 'toolbar/ai_objects_toolbar.dart';
import 'toolbar/color_picker_toolbar.dart';
import 'toolbar/effects_toolbar.dart';
import 'panels/ai_suggestion_panel.dart';
import 'editor_provider.dart';

class EditorScreen extends ConsumerStatefulWidget {
  final EditItem? item;

  const EditorScreen({super.key, this.item});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(editorProvider.notifier).loadImage(widget.item!);
      });
    }
  }

  @override
  void dispose() {
    ref.read(editorProvider.notifier).reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editorProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(),
            const Expanded(child: EditorCanvas()),
            _ModeTabBar(currentMode: state.mode),

            // 모드별 툴바 (AnimatedSize로 슬라이드 인/아웃)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: _buildBottomPanel(state),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel(EditorState state) {
    switch (state.mode) {
      case EditorMode.colorSelect:
        return const ColorPickerToolbar();
      case EditorMode.effects:
        return const EffectsToolbar();
      case EditorMode.aiObject:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            AiObjectsToolbar(),
            AiSuggestionPanel(),
          ],
        );
      case EditorMode.brush:
        return const BrushToolbar();
    }
  }
}

// ── 상단 바 ────────────────────────────────────────────────────
class _TopBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorProvider);

    return Container(
      height: AppSizes.topBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.xs),
      color: Colors.black,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 20),
            onPressed: () => context.pop(),
          ),

          const Spacer(),

          ShaderMask(
            shaderCallback: (bounds) =>
                AppColors.primaryGradient.createShader(bounds),
            child: const Text(
              AppStrings.appName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          const Spacer(),

          IconButton(
            icon: Icon(
              Icons.undo,
              color: state.canUndo
                  ? AppColors.textSecondary
                  : AppColors.textTertiary,
              size: 22,
            ),
            onPressed: state.canUndo
                ? () => ref.read(editorProvider.notifier).undo()
                : null,
          ),

          IconButton(
            icon: Icon(
              Icons.redo,
              color: state.canRedo
                  ? AppColors.textSecondary
                  : AppColors.textTertiary,
              size: 22,
            ),
            onPressed: state.canRedo
                ? () => ref.read(editorProvider.notifier).redo()
                : null,
          ),

          Padding(
            padding: const EdgeInsets.only(right: AppSizes.xs),
            child: _SaveButton(),
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isReady = ref.watch(
      editorProvider.select((s) => s.status == EditorStatus.ready),
    );

    return GestureDetector(
      onTap: isReady
          ? () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const ExportScreen(),
              );
            }
          : null,
      child: Opacity(
        opacity: isReady ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md, vertical: AppSizes.xs),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          ),
          child: const Text(
            AppStrings.save,
            style: TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

// ── 하단 모드 탭 바 ─────────────────────────────────────────────
class _ModeTabBar extends ConsumerWidget {
  final EditorMode currentMode;

  const _ModeTabBar({required this.currentMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 64,
      color: AppColors.surface,
      child: Row(
        children: [
          _TabItem(
            icon: Icons.brush_outlined,
            label: AppStrings.brush,
            isSelected: currentMode == EditorMode.brush,
            isEnabled: true,
            onTap: () =>
                ref.read(editorProvider.notifier).setMode(EditorMode.brush),
          ),
          _TabItem(
            icon: Icons.colorize_outlined,
            label: AppStrings.colorSelect,
            isSelected: currentMode == EditorMode.colorSelect,
            isEnabled: true, // Phase 4 ✅
            onTap: () =>
                ref.read(editorProvider.notifier).setMode(EditorMode.colorSelect),
          ),
          _TabItem(
            icon: Icons.auto_awesome_outlined,
            label: AppStrings.aiDetect,
            isSelected: currentMode == EditorMode.aiObject,
            isEnabled: true, // Phase 3 ✅
            onTap: () =>
                ref.read(editorProvider.notifier).setMode(EditorMode.aiObject),
          ),
          _TabItem(
            icon: Icons.blur_on_outlined,
            label: AppStrings.effects,
            isSelected: currentMode == EditorMode.effects,
            isEnabled: true, // Phase 5 ✅
            onTap: () =>
                ref.read(editorProvider.notifier).setMode(EditorMode.effects),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;

  const _TabItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = !isEnabled
        ? AppColors.textTertiary
        : isSelected
            ? AppColors.primary
            : AppColors.textSecondary;

    return Expanded(
      child: GestureDetector(
        onTap: isEnabled ? onTap : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: AppSizes.iconMd),
            const SizedBox(height: AppSizes.xs),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
