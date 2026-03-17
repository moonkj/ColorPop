import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../models/edit_item.dart';
import 'camera_provider.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cameraProvider.notifier).initCamera();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ref.read(cameraProvider.notifier).disposeCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ref.read(cameraProvider.notifier).disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      ref.read(cameraProvider.notifier).initCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cameraProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: switch (state.status) {
        CameraStatus.idle || CameraStatus.initializing => const _LoadingView(),
        CameraStatus.error => _ErrorView(message: state.error),
        _ => _CameraView(state: state),
      },
    );
  }
}

// ── 카메라 뷰 (메인) ────────────────────────────────────────────
class _CameraView extends ConsumerWidget {
  final CameraState state;

  const _CameraView({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. 카메라 프리뷰 (FlutterTexture)
        if (state.textureId >= 0)
          Texture(textureId: state.textureId)
        else
          const ColoredBox(color: Colors.black),

        // 2. 반전 모드 오버레이 (선택 시 미세 색조)
        if (state.isInverseMode)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.08),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),

        // 3. 상단 컨트롤 바
        Positioned(
          top: 0, left: 0, right: 0,
          child: _TopBar(state: state),
        ),

        // 4. 하단 컨트롤 바
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: _BottomBar(state: state),
        ),
      ],
    );
  }
}

// ── 상단 바 ────────────────────────────────────────────────────
class _TopBar extends ConsumerWidget {
  final CameraState state;

  const _TopBar({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Container(
        height: AppSizes.topBarHeight,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xCC000000), Colors.transparent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Row(
          children: [
            // 뒤로가기
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 20),
              onPressed: () => context.pop(),
            ),

            const Spacer(),

            // 앱 이름
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

            // 전면/후면 전환
            IconButton(
              icon: const Icon(Icons.flip_camera_ios_outlined,
                  color: Colors.white, size: 24),
              onPressed: () => ref.read(cameraProvider.notifier).switchCamera(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 하단 바 ────────────────────────────────────────────────────
class _BottomBar extends ConsumerWidget {
  final CameraState state;

  const _BottomBar({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(
            AppSizes.xl, AppSizes.md, AppSizes.xl, AppSizes.lg),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.transparent, Color(0xCC000000)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 반전 모드 토글
            _InverseModeButton(isActive: state.isInverseMode),

            // 촬영 버튼 (Primary)
            _CaptureButton(isCapturing: state.isCapturing),

            // LiDAR 깊이 모드 (지원 기기만 활성)
            _DepthModeButton(hasLiDAR: state.hasLiDAR),
          ],
        ),
      ),
    );
  }
}

// ── 반전 모드 버튼 ──────────────────────────────────────────────
class _InverseModeButton extends ConsumerWidget {
  final bool isActive;

  const _InverseModeButton({required this.isActive});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref.read(cameraProvider.notifier).toggleInverseMode(),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? AppColors.primary : AppColors.overlayDark,
          border: Border.all(
            color: isActive ? AppColors.primary : Colors.white38,
            width: 1.5,
          ),
        ),
        child: Icon(
          Icons.invert_colors_outlined,
          color: isActive ? Colors.white : Colors.white60,
          size: AppSizes.iconMd,
        ),
      ),
    );
  }
}

// ── 촬영 버튼 ──────────────────────────────────────────────────
class _CaptureButton extends ConsumerWidget {
  final bool isCapturing;

  const _CaptureButton({required this.isCapturing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: isCapturing ? null : () => _onCapture(context, ref),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          color: isCapturing ? Colors.white38 : Colors.transparent,
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isCapturing ? null : AppColors.primaryGradient,
              color: isCapturing ? Colors.white54 : null,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onCapture(BuildContext context, WidgetRef ref) async {
    final data = await ref.read(cameraProvider.notifier).capturePhoto();
    if (data == null || !context.mounted) return;

    // JPEG를 임시 파일로 저장 후 편집기로 이동
    final editItem = await _saveToTempFile(data);
    if (editItem != null && context.mounted) {
      context.push('/editor', extra: editItem);
    }
  }

  Future<EditItem?> _saveToTempFile(Uint8List data) async {
    try {
      final dir = await getTemporaryDirectory();
      final path = p.join(dir.path, 'capture_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await File(path).writeAsBytes(data);
      return EditItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        imagePath: path,
        createdAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }
}

// ── LiDAR 깊이 모드 버튼 (A-4) ────────────────────────────────
class _DepthModeButton extends StatelessWidget {
  final bool hasLiDAR;

  const _DepthModeButton({required this.hasLiDAR});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: hasLiDAR ? 1.0 : 0.3,
      child: Tooltip(
        message: hasLiDAR
            ? AppStrings.cameraDepthMode
            : AppStrings.cameraDepthModeUnavailable,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.overlayDark,
            border: Border.all(color: Colors.white38, width: 1.5),
          ),
          child: const Icon(
            Icons.layers_outlined,
            color: Colors.white60,
            size: AppSizes.iconMd,
          ),
        ),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: AppSizes.md),
          Text(
            AppStrings.cameraInitializing,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ── 오류 뷰 ───────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String? message;

  const _ErrorView({this.message});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 20),
              onPressed: () => context.pop(),
            ),
          ),
          const Spacer(),
          const Icon(Icons.camera_alt_outlined,
              color: AppColors.textTertiary, size: 64),
          const SizedBox(height: AppSizes.md),
          Text(
            message ?? AppStrings.cameraError,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
