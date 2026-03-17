import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/router/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 세로 고정 (편집 앱 특성상)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 상태바 스타일 (다크 배경에 밝은 아이콘)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));

  runApp(const ProviderScope(child: GlowApp()));

  // 첫 프레임 렌더링 완료 후 로드 → 플랫폼 채널이 완전히 준비된 시점
  WidgetsBinding.instance.addPostFrameCallback((_) {
    onboardingStatus.load();
  });
}
