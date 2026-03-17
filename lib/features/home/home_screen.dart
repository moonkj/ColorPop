import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../models/edit_item.dart';
import 'home_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(),
            Expanded(
              child: state.isLoading
                  ? const _LoadingView()
                  : state.recentItems.isEmpty
                      ? const _EmptyStateView()
                      : _PhotoGrid(items: state.recentItems),
            ),
            _BottomActionBar(),
          ],
        ),
      ),
    );
  }
}

// ── 상단 바 ────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      child: Row(
        children: [
          // 앱 이름 (그라디언트 텍스트)
          ShaderMask(
            shaderCallback: (bounds) =>
                AppColors.primaryGradient.createShader(bounds),
            child: const Text(
              AppStrings.appName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
            onPressed: () {
              // Phase 8에서 설정 화면 구현
            },
          ),
        ],
      ),
    );
  }
}

// ── 사진 그리드 ────────────────────────────────────────────────
class _PhotoGrid extends ConsumerWidget {
  final List<EditItem> items;

  const _PhotoGrid({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSizes.md, AppSizes.sm, AppSizes.md, AppSizes.sm),
          child: Text(
            AppStrings.recentEdits,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.photoGridSpacing),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSizes.photoGridSpacing,
              mainAxisSpacing: AppSizes.photoGridSpacing,
              childAspectRatio: 1.0,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) => _PhotoCard(item: items[index]),
          ),
        ),
      ],
    );
  }
}

// ── 사진 카드 ──────────────────────────────────────────────────
class _PhotoCard extends ConsumerWidget {
  final EditItem item;

  const _PhotoCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => context.push('/editor', extra: item),
      onLongPress: () => _showDeleteDialog(context, ref),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 이미지
          Image.file(
            File(item.imagePath),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => const _ImageErrorPlaceholder(),
          ),
          // 하단 그라디언트 오버레이
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: AppColors.cardOverlay,
              ),
            ),
          ),
          // 시간 표시
          Positioned(
            left: AppSizes.sm,
            bottom: AppSizes.sm,
            child: Text(
              item.relativeTime,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('삭제', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          '이 사진을 목록에서 삭제하시겠습니까?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              ref.read(homeProvider.notifier).deleteItem(item.id);
              Navigator.pop(context);
            },
            child: const Text('삭제', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ── 빈 상태 뷰 ─────────────────────────────────────────────────
class _EmptyStateView extends StatelessWidget {
  const _EmptyStateView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 아이콘 (그라디언트)
          ShaderMask(
            shaderCallback: (bounds) =>
                AppColors.primaryGradient.createShader(bounds),
            child: const Icon(
              Icons.add_photo_alternate_outlined,
              size: 80,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          Text(
            AppStrings.emptyStateTitle,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            AppStrings.emptyStateSubtitle,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── 로딩 뷰 ───────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }
}

// ── 이미지 오류 플레이스홀더 ────────────────────────────────────
class _ImageErrorPlaceholder extends StatelessWidget {
  const _ImageErrorPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.card,
      child: Icon(Icons.broken_image_outlined, color: AppColors.textTertiary),
    );
  }
}

// ── 하단 액션 바 ───────────────────────────────────────────────
class _BottomActionBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSizes.md, AppSizes.sm, AppSizes.md, AppSizes.md),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          // 카메라 버튼 → 실시간 AI 카메라 화면으로 이동
          Expanded(
            child: _ActionButton(
              icon: Icons.camera_alt_outlined,
              label: AppStrings.camera,
              onTap: () => context.push('/camera'),
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          // 갤러리 버튼 (Primary)
          Expanded(
            flex: 2,
            child: _ActionButton(
              icon: Icons.photo_library_outlined,
              label: AppStrings.gallery,
              isPrimary: true,
              onTap: () async {
                final item =
                    await ref.read(homeProvider.notifier).pickFromGallery();
                if (item != null && context.mounted) {
                  context.push('/editor', extra: item);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          height: AppSizes.actionButtonHeight,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppSizes.actionButtonRadius),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: AppSizes.iconMd),
              const SizedBox(width: AppSizes.xs),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: AppSizes.actionButtonHeight,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSizes.actionButtonRadius),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.textSecondary, size: AppSizes.iconMd),
            const SizedBox(width: AppSizes.xs),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
