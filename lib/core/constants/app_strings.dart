class AppStrings {
  AppStrings._();

  static const String appName = 'ColorPop';
  static const String tagline = 'Black & White World, Selected Colors Alive';

  // 홈
  static const String recentEdits = '최근 편집';
  static const String camera = '카메라';
  static const String gallery = '갤러리';
  static const String emptyStateTitle = '첫 번째 사진을 추가해보세요';
  static const String emptyStateSubtitle = '갤러리에서 사진을 선택하거나\n카메라로 촬영하세요';

  // 에디터
  static const String save = '저장';
  static const String processing = '처리 중...';
  static const String brush = '브러시';
  static const String colorSelect = '색상';
  static const String aiDetect = 'AI';
  static const String effects = '이펙트';
  static const String undo = '실행 취소';
  static const String redo = '다시 실행';

  // 색상 선택 모드
  static const String colorTapHint = '이미지를 탭해서 색상을 선택하세요';
  static const String colorTolerance = '허용 범위';
  static const String colorGrayscaleWarning = '채도가 너무 낮아요. 다른 색상을 선택해보세요';
  static const String colorRangeMode = '범위 선택';
  static const String colorRangeSecondTap = '끝 색상을 탭하세요';
  static const String colorApplying = '색상 마스크 적용 중...';

  // AI 모드
  static const String aiAnalyzing = 'AI 분석 중...';
  static const String aiNoObjects = '감지된 객체가 없어요';
  static const String aiNoObjectsSubtitle = '브러시 모드로 직접 영역을 선택해보세요';
  static const String aiSuggestions = 'AI 추천';
  static const String aiObjects = '감지된 객체';
  static const String aiApplying = '마스크 적용 중...';
  static const String objectLock = '경계 잠금';

  // 이펙트 모드
  static const String effectNone = '없음';
  static const String effectNeonGlow = '네온 글로우';
  static const String effectChromatic = '색수차';
  static const String effectFilmGrain = '필름 그레인';
  static const String effectBgBlur = '배경 블러';
  static const String effectFilmNoir = '필름 누아르';
  static const String effectIntensity = '강도';
  static const String effectInverseMode = '반전 모드';

  // Phase 6: 카메라 모드
  static const String cameraInitializing = '카메라 준비 중...';
  static const String cameraError = '카메라를 사용할 수 없습니다\n권한을 확인해주세요';
  static const String cameraDepthMode = 'LiDAR 깊이 모드';
  static const String cameraDepthModeUnavailable = 'LiDAR 미지원 기기';

  // 오류
  static const String errorImageLoad = '이미지를 불러올 수 없습니다';
  static const String errorProcessing = '이미지 처리 중 오류가 발생했습니다';
  static const String errorPermission = '사진 접근 권한이 필요합니다';

  // Phase 7: Export
  static const String exportTitle = '내보내기';
  static const String exportRendering = '고화질 렌더링 중...';
  static const String exportSavePhoto = '사진 저장';
  static const String exportSavePhotoSub = '기기 사진함에 저장';
  static const String exportShare = '공유하기';
  static const String exportShareSub = 'Instagram, TikTok 등으로 공유';
  static const String exportLoopTitle = 'Loop 영상';
  static const String exportLoopDesc = 'B&W → Color → B&W 3초 루프 영상을 생성합니다\nInstagram Reels, TikTok에 최적화';
  static const String exportLoopShare = '영상 공유';
  static const String exportLoopSave = '영상 저장';
  static const String exportSaveSuccess = '사진이 저장되었습니다';
  static const String exportLoopSaveSuccess = 'Loop 영상이 저장되었습니다';
  static const String exportLoopGenerating = 'Loop 영상 생성 중...';
  static const String exportPermissionError = '사진 접근 권한이 필요합니다\n설정에서 권한을 허용해주세요';

  // 시간 표시
  static const String justNow = '방금 전';
  static const String minutesAgo = '분 전';
  static const String hoursAgo = '시간 전';
  static const String daysAgo = '일 전';
}
