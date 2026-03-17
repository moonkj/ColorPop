# ColorPop — 상세 구현 계획서

> **버전**: 1.6.0
> **작성일**: 2026-03-17
> **최종 업데이트**: 2026-03-17 (Phase 6 카메라 모드 구현 완료)
> **스택**: Flutter 3.41+ / Swift (iOS Native) / Metal / Core Image / CoreML

---

## 목차

1. [제품 비전 및 핵심 철학](#1-제품-비전-및-핵심-철학)
2. [기술 아키텍처 개요](#2-기술-아키텍처-개요)
3. [렌더링 파이프라인](#3-렌더링-파이프라인)
4. [프로젝트 파일 구조](#4-프로젝트-파일-구조)
5. [구현 단계 (Phase 계획)](#5-구현-단계-phase-계획)
6. [핵심 시스템별 상세 설계](#6-핵심-시스템별-상세-설계)
7. [AI 세그멘테이션 설계](#7-ai-세그멘테이션-설계)
8. [Mask 레이어 시스템](#8-mask-레이어-시스템)
9. [브러시 시스템 상세](#9-브러시-시스템-상세)
10. [Undo/Redo 시스템](#10-undoredo-시스템)
11. [바이럴 이펙트 시스템](#11-바이럴-이펙트-시스템)
12. [카메라 모드 설계](#12-카메라-모드-설계)
13. [소셜 공유 및 Export](#13-소셜-공유-및-export)
14. [성능 최적화 전략](#14-성능-최적화-전략)
15. [수익화 구조](#15-수익화-구조)
16. [나의 추가 아이디어 및 차별화 포인트](#16-나의-추가-아이디어-및-차별화-포인트)
17. [개발 일정 로드맵](#17-개발-일정-로드맵)
18. [완료 체크리스트](#18-완료-체크리스트)

---

## 1. 제품 비전 및 핵심 철학

### 핵심 슬로건
> **"Black & White World, Selected Colors Alive"**

### 편집 철학
```
Capture → AI Analyze → 1 Tap Color Splash → Share
```

ColorPop은 단순한 Color Splash 앱이 아니다.
다음 세 가지의 결합이 진짜 경쟁력이다:

| 요소 | 설명 |
|------|------|
| AI Detection | CoreML + Vision으로 자동 피사체 인식 |
| Mask Editing | GPU 기반 실시간 브러시/선택/AI 마스킹 |
| Viral Effects | Neon Glow, Chromatic Aberration 등 SNS 특화 이펙트 |
| Camera Mode | 실시간 AI 미리보기로 즉시 촬영 |

### 타겟 유저
- Gen Z (18~25세) 소셜 크리에이터
- 복잡한 툴 없이 임팩트 있는 결과를 원하는 사용자
- Instagram Reels, TikTok, Snapchat 공유 목적 사용자

---

## 2. 기술 아키텍처 개요

### 레이어 구조

```
┌─────────────────────────────────────────┐
│            Flutter UI Layer             │  ← Dart (Flutter 3.41)
│  Navigation / State / Widget Tree       │
└─────────────┬───────────────────────────┘
              │ Platform Channel (Method/Event Channel)
┌─────────────▼───────────────────────────┐
│         iOS Native Bridge Layer         │  ← Swift
│  ImageProcessor / CameraEngine          │
│  AISegmentationEngine / MaskEngine      │
└──────┬──────────┬───────────────────────┘
       │          │
┌──────▼──┐  ┌───▼──────────────────────┐
│  Metal  │  │      Core Image          │  ← GPU 가속
│ Shaders │  │  CIBlendWithMask         │
│  (MSL)  │  │  CIColorControls         │
└─────────┘  └──────────────────────────┘
       │
┌──────▼───────────────────────────────────┐
│         CoreML / Vision Framework        │  ← AI
│  VNGeneratePersonSegmentationRequest     │
│  VNRecognizeObjectsRequest               │
│  VNDetectRectanglesRequest               │
└──────────────────────────────────────────┘
```

### 핵심 기술 스택

| 영역 | 기술 | 용도 |
|------|------|------|
| UI | Flutter 3.41 | 전체 UI, 상태관리, 라우팅 |
| 상태관리 | Riverpod 2.x | 앱 전역 상태 |
| 이미지 처리 | Core Image + Metal | GPU 기반 합성, 필터 |
| AI | CoreML + Vision | 객체 감지, 세그멘테이션 |
| 카메라 | AVFoundation | 실시간 카메라 피드 |
| 브리지 | Flutter Platform Channel | Dart ↔ Swift 통신 |
| 저장 | Photos Framework | 기기 사진 라이브러리 저장 |
| 공유 | UIActivityViewController | 소셜 공유 |

---

## 3. 렌더링 파이프라인

### 기본 합성 공식

```
Final = (Grayscale × Mask) + (Color × (1 - Mask)) + FX(Color × (1 - Mask))
```

### 4-레이어 합성 구조

```
Layer 4 (Top)    : FX Layer     — 컬러 영역 이펙트 (Glow, Glitch, Sparkle)
Layer 3          : Grayscale    — 흑백 이미지 (Mask=1인 영역 표시)
Layer 2 (Core)   : Alpha Mask  — 0.0~1.0 float 마스크 (핵심 데이터)
Layer 1 (Bottom) : Color Image  — 원본 컬러 이미지
```

### Metal Shader 렌더링 흐름

```
[ Original Texture ]
        ↓
[ Grayscale Shader ]     ← CIColorControls (saturation: 0)
        ↓
[ Mask Texture ] ←─── Brush Paint / AI Seg / Color Select
        ↓
[ Blend Shader ]         ← kernel: final = mix(color, gray, mask)
        ↓
[ FX Shader Pass ]       ← Neon Glow / RGB Split / Sparkle
        ↓
[ Output Texture → Flutter Texture Widget ]
```

### Metal Shader 핵심 코드 설계

```metal
// ColorPopBlend.metal
fragment float4 colorPopFragment(
    VertexOut in [[stage_in]],
    texture2d<float> colorTex [[texture(0)]],
    texture2d<float> grayTex  [[texture(1)]],
    texture2d<float> maskTex  [[texture(2)]]
) {
    float4 color = colorTex.sample(sampler, in.uv);
    float4 gray  = grayTex.sample(sampler, in.uv);
    float  mask  = maskTex.sample(sampler, in.uv).r;

    // Soft blend: color 영역에 살짝 warm toning
    float4 result = mix(color, gray, mask);
    return result;
}
```

---

## 4. 프로젝트 파일 구조

```
ColorPop/
├── lib/                                 # Flutter/Dart
│   ├── main.dart                        # 앱 진입점
│   ├── app.dart                         # MaterialApp 설정
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_colors.dart          # 브랜드 색상
│   │   │   ├── app_sizes.dart           # 공통 사이즈
│   │   │   └── app_strings.dart         # 텍스트 상수
│   │   ├── theme/
│   │   │   └── app_theme.dart           # Gen Z 다크 테마
│   │   └── router/
│   │       └── app_router.dart          # GoRouter 라우팅
│   │
│   ├── features/
│   │   ├── home/
│   │   │   ├── home_screen.dart         # 홈 (갤러리 피드)
│   │   │   └── home_provider.dart
│   │   │
│   │   ├── camera/
│   │   │   ├── camera_screen.dart       # 실시간 카메라
│   │   │   ├── camera_preview_widget.dart
│   │   │   └── camera_provider.dart
│   │   │
│   │   ├── editor/
│   │   │   ├── editor_screen.dart       # 메인 편집 화면
│   │   │   ├── canvas/
│   │   │   │   ├── editor_canvas.dart   # 편집 캔버스 (GestureDetector)
│   │   │   │   ├── brush_painter.dart   # CustomPainter 브러시
│   │   │   │   └── magnifier_lens.dart  # 돋보기 위젯
│   │   │   ├── toolbar/
│   │   │   │   ├── brush_toolbar.dart   # 브러시 설정 바
│   │   │   │   ├── color_picker_toolbar.dart
│   │   │   │   ├── ai_objects_toolbar.dart
│   │   │   │   └── effects_toolbar.dart
│   │   │   ├── panels/
│   │   │   │   ├── ai_suggestion_panel.dart   # AI 추천 칩
│   │   │   │   ├── effect_panel.dart           # 이펙트 선택
│   │   │   │   └── adjustment_panel.dart       # 밝기/대비 조정
│   │   │   └── editor_provider.dart     # 편집 상태 관리
│   │   │
│   │   ├── effects/
│   │   │   ├── effects_screen.dart
│   │   │   └── effects_provider.dart
│   │   │
│   │   └── export/
│   │       ├── export_screen.dart       # 내보내기 화면
│   │       ├── share_template_widget.dart
│   │       └── export_provider.dart
│   │
│   ├── services/
│   │   ├── image_processing_service.dart  # Platform Channel 래퍼
│   │   ├── ai_segmentation_service.dart   # AI 세그 채널
│   │   ├── camera_service.dart            # 카메라 채널
│   │   └── export_service.dart            # 내보내기 채널
│   │
│   ├── models/
│   │   ├── mask_data.dart               # 마스크 데이터 모델
│   │   ├── brush_settings.dart          # 브러시 설정
│   │   ├── edit_history.dart            # Undo/Redo 히스토리
│   │   ├── detected_object.dart         # AI 감지 객체
│   │   ├── ai_suggestion.dart           # AI 추천 모델
│   │   └── effect_config.dart           # 이펙트 설정
│   │
│   └── widgets/
│       ├── before_after_slider.dart     # Before/After 비교
│       ├── color_chip.dart              # 컬러 선택 칩
│       ├── object_chip.dart             # 객체 선택 칩
│       └── haptic_button.dart           # 햅틱 피드백 버튼
│
├── ios/
│   └── Runner/
│       ├── AppDelegate.swift
│       ├── Channels/
│       │   ├── ImageProcessingChannel.swift    # 이미지 처리 채널
│       │   ├── AISegmentationChannel.swift     # AI 채널
│       │   └── CameraChannel.swift             # 카메라 채널
│       ├── ImageEngine/
│       │   ├── ColorPopImageProcessor.swift    # 핵심 이미지 처리
│       │   ├── MaskEngine.swift                # 마스크 연산
│       │   ├── BrushEngine.swift               # 브러시 페인팅
│       │   ├── ColorSelectEngine.swift         # 색상 선택
│       │   └── EdgeRefinementEngine.swift      # 엣지 보정
│       ├── AI/
│       │   ├── PersonSegmentationEngine.swift  # 인물 세그
│       │   ├── ObjectDetectionEngine.swift     # 객체 감지
│       │   ├── SmartPaletteEngine.swift        # 색상 추천 AI
│       │   └── AlphaMattingEngine.swift        # Alpha Matting
│       ├── Camera/
│       │   ├── CameraEngine.swift              # AVFoundation 카메라
│       │   └── RealtimeProcessor.swift         # 실시간 처리
│       ├── Effects/
│       │   ├── NeonGlowEffect.swift
│       │   ├── ChromaticAberrationEffect.swift
│       │   ├── SparkleEffect.swift
│       │   └── FilmGrainEffect.swift
│       ├── Export/
│       │   ├── ExportEngine.swift              # 고해상도 내보내기
│       │   └── LoopVideoGenerator.swift        # Reels용 루프 영상
│       └── Metal/
│           ├── ColorPopBlend.metal             # 핵심 합성 셰이더
│           ├── NeonGlow.metal                  # 네온 글로우 셰이더
│           ├── ChromaticAberration.metal       # RGB 분열 셰이더
│           ├── TemporalSmoothing.metal         # 카메라 지터 방지
│           └── DepthAwareMask.metal            # Depth 기반 마스킹
│
├── assets/
│   ├── images/                          # UI 이미지
│   ├── icons/                           # 앱 아이콘
│   ├── lottie/                          # 로딩 애니메이션
│   └── ml_models/                       # CoreML 모델 (필요시)
│
└── process.md                           # 이 파일
```

---

## 5. 구현 단계 (Phase 계획)

### Phase 1 — 기반 구조 (2주)
> 목표: 앱이 실행되고 기본 편집이 가능한 상태

- [ ] Flutter 프로젝트 구조 설정 (폴더/파일 생성)
- [ ] Riverpod, GoRouter, 기타 패키지 설치
- [ ] 다크 테마 (Gen Z 스타일) 적용
- [ ] 홈 화면 UI (갤러리 그리드)
- [ ] 이미지 선택 (ImagePicker)
- [ ] iOS Platform Channel 기반 구조 구축
- [ ] 기본 흑백 변환 (Core Image)
- [ ] Flutter Texture Widget으로 네이티브 이미지 렌더링

### Phase 2 — 마스크 & 브러시 (2주)
> 목표: 수동 브러시 편집이 작동하는 MVP

- [ ] Mask 데이터 구조 설계 (Float 배열 / MTLTexture)
- [ ] GPU 기반 Blend Shader (Metal) 구현
- [ ] 브러시 페인팅 엔진 (Swift + Metal)
- [ ] Flutter GestureDetector → 터치 좌표 → Native 브러시 전달
- [ ] 브러시 크기/부드러움 조절 UI
- [ ] 돋보기 렌즈 위젯
- [ ] 기본 Undo/Redo (Mask 스냅샷 방식)
- [ ] Zoom/Pan (InteractiveViewer)

### Phase 3 — AI 세그멘테이션 (2주)
> 목표: AI 원터치 배경 분리

- [ ] VNGeneratePersonSegmentationRequest 구현
- [ ] Alpha Matting 옵션 활성화 (머리카락 처리)
- [ ] Guided Filter 엣지 보정
- [ ] 객체 감지 (VNRecognizeObjectsRequest or CoreML YOLOv8)
- [ ] 객체 칩 UI (Person, Car, Sky 등)
- [ ] "Select All Non-Subject" 칩 추가
- [ ] AI 추천 시스템 (Smart Palette Suggestion)
- [ ] AI 제안 패널 UI

### Phase 4 — Selective Color (1주)
> 목표: 탭으로 색상 선택해서 해당 색만 컬러 유지

- [ ] HSL 색공간 기반 색상 범위 계산
- [ ] 색상 피커 UI (Tap on image)
- [ ] 허용 오차(Tolerance) 슬라이더
- [ ] 색상 마스크 → Blend Shader에 전달
- [ ] Tap-to-Color 인터랙션 (이미지 픽셀 샘플링)

### Phase 5 — 이펙트 시스템 (2주)
> 목표: 바이럴 이펙트로 SNS 공유욕 자극

- [ ] Neon Glow (Metal Shader)
- [ ] Chromatic Aberration / RGB Split
- [ ] Sparkle 효과
- [ ] Film Grain
- [ ] Light Leak
- [ ] Background Blur (컬러 영역 외 블러)
- [ ] Film Noir 스타일 (배경 영역)
- [ ] Inverse Mode (피사체만 흑백, 배경 네온)
- [ ] FX 강도 슬라이더 (실시간)

### Phase 6 — 카메라 모드 (2주)
> 목표: 실시간 AI 미리보기 + 촬영

- [ ] AVFoundation 카메라 세션 구현
- [ ] 실시간 AI 세그멘테이션 (30fps 목표)
- [ ] Temporal Smoothing (Exponential Moving Average, Metal)
- [ ] Flutter Texture Widget으로 카메라 피드 렌더링
- [ ] 촬영 버튼 → 고해상도 캡처
- [ ] Depth-Aware Splash (LiDAR 기기 한정)

### Phase 7 — Export & 공유 (1주)
> 목표: 고품질 내보내기 + 소셜 공유

- [ ] 원본 해상도 최종 합성 렌더링
- [ ] JPG/PNG 내보내기
- [ ] Loop 영상 자동 생성 (B&W → Color 3~5초, Reels용)
- [ ] Before/After 슬라이더 위젯
- [ ] UIActivityViewController 공유
- [ ] 공유 템플릿 (Original | Splash, Before | After)

### Phase 8 — 수익화 & 완성도 (1주)
> 목표: 출시 준비

- [ ] RevenueCat StoreKit 연동
- [ ] 프리미엄 기능 잠금 처리
- [ ] 온보딩 화면 (3단계 튜토리얼)
- [ ] 햅틱 피드백 전체 적용
- [ ] 퍼포먼스 프로파일링 (Instruments)
- [ ] TestFlight 배포

---

## 6. 핵심 시스템별 상세 설계

### 편집기 상태 구조 (Riverpod)

```dart
// EditorState
class EditorState {
  final Uint8List? originalImage;
  final MaskData maskData;
  final EditMode currentMode;       // brush, colorSelect, aiObject
  final BrushSettings brushSettings;
  final List<DetectedObject> detectedObjects;
  final List<AiSuggestion> suggestions;
  final EffectConfig effectConfig;
  final EditHistory history;
  final bool isProcessing;
}

enum EditMode { brush, erase, colorSelect, aiObject, camera }
```

### Platform Channel 설계

```dart
// image_processing_service.dart
class ImageProcessingService {
  static const _channel = MethodChannel('com.colorpop/image');

  Future<Uint8List> applyMaskBlend({
    required Uint8List colorImage,
    required Uint8List maskData,
    required EffectConfig effects,
  }) async { ... }

  Future<void> paintBrush({
    required Offset position,
    required BrushSettings settings,
    required bool isReveal,  // true=color reveal, false=erase
  }) async { ... }

  Future<MaskData> selectColor({
    required Color selectedColor,
    required double tolerance,
  }) async { ... }
}
```

---

## 7. AI 세그멘테이션 설계

### 인물 세그멘테이션 (Apple Vision)

```swift
// PersonSegmentationEngine.swift
class PersonSegmentationEngine {
    func segment(pixelBuffer: CVPixelBuffer) async -> CIImage? {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate       // 정확도 우선
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8

        // Alpha Matting 활성화 (iOS 16+)
        // 머리카락 등 미세한 경계 처리
        if #available(iOS 17.0, *) {
            // Person matte from AVPortraitEffectsMatte
        }

        // Guided Filter로 엣지 보정
        let mask = applyGuidedFilter(mask: rawMask, guide: originalImage)
        return mask
    }
}
```

### 객체 감지 파이프라인

```
VNRecognizeObjectsRequest
         ↓
  [Person, Car, Dog, Sky, Food, Building, ...]
         ↓
  Flutter에 DetectedObject 배열 전달
         ↓
  UI: 객체 칩 렌더링
         ↓
  유저 탭 → 해당 객체 마스크 생성
```

### AI 추천 시스템 (Smart Palette)

이미지 분석 후 3가지 추천 생성:

```swift
struct AISuggestion {
    let title: String          // "Try highlighting the person"
    let maskType: MaskType     // .person, .color(Color), .object(String)
    let previewThumbnail: UIImage
    let confidenceScore: Float
}

// 예시 추천 로직:
// 1. 인물 감지 → "인물 하이라이트 추천"
// 2. 채도 높은 색상 추출 → "빨간 자동차 추천"
// 3. 하늘 감지 → "하늘 블루 추천"
```

---

## 8. Mask 레이어 시스템

### Mask 데이터 구조

```swift
// MaskEngine.swift
class MaskEngine {
    // Metal Texture로 GPU에 유지 (CPU ↔ GPU 복사 최소화)
    var maskTexture: MTLTexture        // R32Float, preview 해상도
    var fullResMaskTexture: MTLTexture // 원본 해상도 (export용)

    // 마스크 연산
    func paintBrush(at point: CGPoint, settings: BrushSettings) { ... }
    func applyAISegmentation(_ mask: CIImage) { ... }
    func applyColorSelection(hsl: HSLRange) { ... }
    func eraseAt(point: CGPoint, radius: Float) { ... }
    func refineEdges() { ... }

    // 스냅샷 (Undo용)
    func takeSnapshot() -> MTLTexture { ... }
    func restoreSnapshot(_ texture: MTLTexture) { ... }
}
```

### 프리뷰 vs 익스포트 해상도

| 용도 | 해상도 | 이유 |
|------|--------|------|
| 편집 프리뷰 | 기기 화면 너비 × 2 (Retina) | 선명한 편집 피드백 |
| 최종 내보내기 | 원본 사진 해상도 | 최고 품질 |
| 카메라 모드 | 1080p | 30fps 유지 |

---

## 9. 브러시 시스템 상세

### 브러시 파라미터

```dart
class BrushSettings {
  final double size;       // 10~200px
  final double softness;   // 0.0~1.0 (Gaussian blur 반경)
  final double opacity;    // 0.0~1.0
  final BrushMode mode;    // reveal (color) / erase (gray)
}
```

### Smart Edge Lock (스마트 엣지 잠금)

```swift
// EdgeRefinementEngine.swift
// 브러시가 엣지 근처에서 경계를 존중하도록 함
func applyEdgeLock(brushMask: MTLTexture, edgeMap: MTLTexture) -> MTLTexture {
    // Canny Edge Detection으로 엣지 맵 생성
    // 브러시 마스크 × (1 - edgeMap) → 엣지를 넘어가지 않음
    // Metal Shader로 GPU 처리
}
```

### 브러시 소프트니스 (Feathering)

```metal
// BrushStroke.metal
fragment float4 brushFragment(...) {
    float dist = distance(in.uv, brushCenter);
    float normalizedDist = dist / brushRadius;

    // Gaussian falloff
    float alpha = exp(-normalizedDist * normalizedDist * (1.0 / softness));
    alpha = clamp(alpha, 0.0, 1.0);

    return float4(alpha, 0, 0, 1); // R 채널이 마스크 값
}
```

---

## 10. Undo/Redo 시스템

### Hybrid 전략 (권장)

```
브러시 획 1~9  : Delta 저장 (변경된 픽셀 좌표 + 값만)
브러시 획 10   : 전체 마스크 스냅샷 저장
브러시 획 11~19: Delta 저장
브러시 획 20   : 전체 마스크 스냅샷 저장
...
```

```swift
class EditHistory {
    private var snapshots: [MTLTexture] = []  // 10회마다 스냅샷
    private var deltas: [[MaskDelta]] = []     // 스냅샷 사이 델타
    private var currentIndex = 0

    struct MaskDelta {
        let affectedRect: CGRect
        let previousData: Data
        let newData: Data
    }

    func undo() {
        // 현재 위치에서 delta를 역적용하거나
        // 이전 스냅샷으로 복원
    }

    func redo() { ... }

    // 메모리 관리: 최대 50단계 유지
    private let maxHistory = 50
}
```

---

## 11. 바이럴 이펙트 시스템

### 컬러 영역 이펙트

| 이펙트 | 구현 방식 | 효과 |
|--------|-----------|------|
| Neon Glow | Metal + Gaussian Blur + Additive Blend | 빛나는 네온 느낌 |
| Chromatic Aberration | RGB 채널 오프셋 | 사이버펑크 글리치 |
| Sparkle | Particle System Metal | 반짝이는 별 |
| Film Grain | Perlin Noise Shader | 필름 감성 |
| Light Leak | Gradient Overlay Blend | 필름 빛샘 |
| RGB Glow | Multi-pass Bloom | 강한 발광 |

### 배경 영역 이펙트

| 이펙트 | 구현 방식 | 효과 |
|--------|-----------|------|
| Background Blur | CIGaussianBlur (마스크 인버스) | DSLR 보케 느낌 |
| Film Noir | CIColorControls + Contrast | 고전 영화 느낌 |
| Vintage Grain | Noise + Sepia | 빈티지 필름 |
| Soft Vignette | Radial Gradient Mask | 중앙 집중 |

### Inverse Mode (차별화 기능)
```
일반: 피사체=Color, 배경=B&W
Inverse: 피사체=B&W, 배경=Neon Color
```
원터치로 마스크를 반전시키고 배경에 네온 이펙트 적용.
도시 야경, 파티 사진에서 몽환적 연출 가능.

### FX 렌더링 패스 설계

```swift
// Effects/NeonGlowEffect.swift
class NeonGlowEffect {
    func apply(
        colorRegion: CIImage,  // 컬러 영역만
        mask: CIImage,
        intensity: Float       // 0.0~1.0 실시간 조절
    ) -> CIImage {
        // 1. 컬러 영역 추출
        // 2. Gaussian Blur (radius: intensity * 20)
        // 3. Additive blend with original
        // 4. Mask로 컬러 영역에만 적용
    }
}
```

---

## 12. 카메라 모드 설계

### 실시간 처리 파이프라인

```
AVCaptureSession (60fps capture)
        ↓
AVCaptureVideoDataOutput
        ↓
[Metal Command Buffer]
  ├── PersonSegmentation (VNRequest, 15fps)
  ├── TemporalSmoothing (60fps, Exponential MA)
  └── ColorPopBlend Shader (60fps)
        ↓
[Flutter Texture Widget] → 화면 렌더링
```

### Temporal Smoothing (지터 방지)

```metal
// TemporalSmoothing.metal
// 이전 프레임 마스크와 현재 마스크를 가중 평균
// α = 0.3 (새 프레임 반영 비율)
fragment float4 temporalSmoothFragment(...) {
    float currentMask = currentMaskTex.sample(s, uv).r;
    float prevMask    = prevMaskTex.sample(s, uv).r;
    float smoothed    = mix(prevMask, currentMask, alpha); // α=0.3
    return float4(smoothed, 0, 0, 1);
}
```

### Depth-Aware Splash (LiDAR 기기)

```swift
// LiDAR 지원 기기에서 Depth 데이터 활용
if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
    // Depth 데이터 → 거리 임계값 마스크 생성
    // "나로부터 2m 이내 = 컬러, 그 외 = 흑백+블러"
}
```

---

## 13. 소셜 공유 및 Export

### Export 종류

| 타입 | 해상도 | 포맷 | 플랜 |
|------|--------|------|------|
| 기본 내보내기 | 최대 2048px | JPG | 무료 |
| 고해상도 | 원본 해상도 | PNG/JPG | Pro |
| Loop 영상 | 1080p | MP4 (H.264) | Pro |
| Before/After | 원본 | JPG | 무료 |

### Loop 영상 자동 생성 (핵심 바이럴 기능)

```swift
// LoopVideoGenerator.swift
// B&W → Color → B&W 3초 루프 생성
// 마스크의 투명도를 0→1→0으로 애니메이션
class LoopVideoGenerator {
    func generate(
        colorImage: UIImage,
        maskData: MaskData,
        duration: Double = 3.0    // 3초
    ) async -> URL {
        // AVAssetWriter로 MP4 생성
        // Metal로 각 프레임 렌더링 (마스크 투명도 보간)
        // 30fps × 3초 = 90 프레임
    }
}
```

### 공유 템플릿

```
[ Original | Splash ]  ← 좌우 분할
[ Before   | After  ]  ← 좌우 분할 (슬라이더)
[ Full Result ]         ← 편집 결과만
```

---

## 14. 성능 최적화 전략

### GPU 메모리 관리

```swift
// MTLTexture 재사용 풀
class TexturePool {
    private var pool: [MTLTexture] = []

    func acquire(descriptor: MTLTextureDescriptor) -> MTLTexture { ... }
    func release(_ texture: MTLTexture) { ... }
}
```

### 렌더링 최적화

| 전략 | 설명 |
|------|------|
| Tile-based Rendering | 브러시 획 시 변경된 타일만 재렌더링 |
| Lazy Mask Update | 브러시 드래그 중: 200ms debounce |
| Preview Downscale | 편집 중: Retina 해상도, Export 시: 원본 |
| Command Buffer Reuse | Metal Command Buffer 매 프레임 재생성 방지 |
| Background Queue | AI 세그멘테이션을 백그라운드 큐에서 실행 |

### AI 처리 주기

```
카메라 모드: AI 15fps → Temporal Smoothing 60fps
편집 모드: AI 1회 실행 후 마스크 재사용
색상 선택: CPU HSL 계산 (간단한 연산, GPU 불필요)
```

---

## 15. 수익화 구조

### 무료 티어

- 기본 브러시 편집
- 색상 선택 (Selective Color)
- 최대 2048px 내보내기 (JPG)
- 기본 이펙트 2~3가지
- 워터마크 포함

### Pro 구독 ($3.99/월 or $29.99/년)

- AI 세그멘테이션 (무제한)
- 모든 바이럴 이펙트
- 원본 해상도 내보내기 (PNG/JPG)
- Loop 영상 자동 생성
- 워터마크 없음
- 카메라 AI 모드
- Depth-Aware Splash

### RevenueCat 연동

```dart
// Flutter에서 RevenueCat SDK 사용
// Paywall UI는 SuperwallKit 또는 커스텀 구현
```

---

## 16. 통합 아이디어 및 차별화 포인트

기획서 제안 아이디어 + Claude 추가 아이디어를 통합 정리.

---

### A. 기획서 보완 제안 아이디어 (사용자 원안)

#### A-1. Alpha Matting (머리카락/모피 처리)
VNGeneratePersonSegmentationRequest의 Matte 옵션 활성화 + Guided Filter 후처리.
일반 Segmentation의 칼날 경계를 부드러운 반투명 경계로 변환.
```
Raw AI Mask → Alpha Matte → Guided Filter → Soft Edge Mask
```

#### A-2. Temporal Consistency (카메라 지터 방지)
실시간 카메라 모드에서 AI 마스크가 프레임마다 미세하게 떨리는 현상 방지.
이전 프레임 마스크 × 0.7 + 현재 프레임 마스크 × 0.3 = 부드러운 마스크.
Metal Shader 내 Exponential Smoothing 로직으로 구현.

#### A-3. The "Inverse" Surprise Mode
- 일반: 피사체=Color, 배경=B&W
- Inverse: 피사체=B&W, 배경=네온 컬러
도시 야경에서 사람만 무채색 → 몽환적/예술적 연출.
마스크 반전(1-mask) 한 번으로 구현 가능. 원터치 토글 UI.

#### A-4. Depth-Aware Splash (공간 깊이 기반)
LiDAR 또는 듀얼 카메라 Depth 데이터 활용.
"나로부터 2m 이내 = 컬러, 그 외 = 흑백+블러" 거리 임계값 마스킹.
슬라이더로 거리 임계값 실시간 조절 → 공간감 극대화.

#### A-5. Smart Palette Suggestion (AI 색상 추천)
사진 분석 후 가장 채도 높은 색상 2~3가지를 자동 추천.
"이 사진은 Sky Blue를 살렸을 때 가장 힙해요!" 형태의 원탭 추천 카드.
구현: CIAreaAverage + 히스토그램 분석 → 채도 높은 Top3 색상 추출.

#### A-6. Haptic Feedback (손맛)
브러시가 AI 엣지(경계선)를 감지할 때 미세 진동.
UIImpactFeedbackGenerator(.light)로 경계면 도달 시 햅틱 발생.
"내가 경계를 잘 지키고 있다"는 촉각적 피드백.

#### A-7. Instant Loop Export (Reels 자동 생성)
저장 시 B&W → Color 서서히 변하는 3~5초 루프 영상 자동 생성.
AVAssetWriter + Metal 프레임 렌더링으로 MP4 생성.
인스타그램 스토리/Reels에 바로 공유 가능.

#### A-8. Hybrid Undo 시스템
10회마다 전체 마스크 스냅샷 + 그 사이는 Delta 저장.
메모리와 성능을 동시에 최적화하는 혼합 방식.

#### A-9. Retina 기반 프리뷰 해상도
기기 화면 너비 × 2 = 프리뷰 해상도 (예: iPhone Pro = 1290 × 2 = 2580px).
1024px 고정 대비 고해상도 기기에서 선명한 편집 피드백.

#### A-10. "Select All Non-Subject" 칩
AI 감지 객체 UI에 "나머지 전체 선택" 칩 추가.
주제를 제외한 모든 영역을 한 번에 흑백 처리.

---

### B. Claude 추가 아이디어

#### B-1. Emotion-Based AI Splash
얼굴 감정 인식 AI (CoreML VNDetectFaceLandmarksRequest) 연동.
- 기쁨 → 따뜻한 황금빛 색상 추천
- 강렬한 표정 → 사이버펑크 네온
- 차분한 표정 → 파스텔 톤

```swift
// FaceEmotionEngine.swift
// VNDetectFaceLandmarksRequest → AU(Action Unit) 분석
// → 감정 레이블 → AISuggestion 생성
enum Emotion { case joy, intense, calm, neutral }
func suggestSplashForEmotion(_ emotion: Emotion) -> ColorPalette
```

#### B-2. Color Story (Multi-Frame Narrative)
사진 3~5장 선택 → 각 사진마다 다른 색상 살리기 → 자동 연결 영상 생성.
빨강 → 파랑 → 황금빛으로 이어지는 컬러 내러티브.
Instagram Carousel / TikTok 슬라이드쇼 포맷 최적화.

#### B-3. Sound-Reactive Splash (Pro)
음악 비트에 맞춰 Neon Glow 강도가 실시간 변화하는 영상 생성.
```
AVAudioEngine → FFT → Beat Detection → Metal Uniform 업데이트
→ Glow Intensity ∝ Beat Amplitude
```
TikTok 음악 영상 콘텐츠로 최적화.

#### B-4. AR Splash Preview
ARKit을 활용한 실시간 흑백+컬러 세계 뷰파인더.
찍기 전에 결과를 AR로 미리 "보는" 경험.
구현: ARSCNView + Metal Post-processing.

#### B-5. Palette History & Community
사용자가 만든 "팔레트 + 이펙트 조합"을 preset으로 저장/공유.
커뮤니티 인기 preset 다운로드 → 원탭 적용.
예시 preset: "사이버펑크 서울", "빈티지 도쿄", "네온 파리".

#### B-6. Gradient Color Range Splash
단일 색상이 아닌 두 색상 사이의 범위 선택.
Color Wheel에서 시작·끝 색상 지정 → 그 사이 모든 색상 컬러 유지.
예: 노을 사진에서 주황~빨강 계열만 살리기.

```swift
// ColorSelectEngine.swift 확장
func selectGradientRange(from: HSL, to: HSL, tolerance: Float) -> MTLTexture {
    // Hue 범위 [from.hue ... to.hue] 내 픽셀만 mask=0
}
```

#### B-7. Smart Object Lock (자동 엣지 잠금)
AI 감지 객체 경계를 자동으로 엣지락 영역으로 설정.
브러시로 대충 칠해도 AI 경계 안에서만 마스킹 적용.
초보자도 전문가급 결과 획득.

```swift
// BrushEngine.swift 내
func paintWithObjectLock(at point: CGPoint, objectMask: MTLTexture) {
    // brushStroke ∩ objectMask = 실제 적용 마스크
}
```

#### B-8. "Rewind" 편집 타임랩스 공유
편집 과정(브러시 획들)을 기록 → 1~2초 타임랩스 영상으로 압축.
완성 과정 자체가 TikTok 콘텐츠가 됨.

```swift
// EditRewindRecorder.swift
// 브러시 획마다 마스크 썸네일 캡처 → Metal로 프레임 합성 → MP4
```

#### B-9. Contextual Scene Splash (신규)
AI가 장면(Scene) 전체를 분석하여 "이 장면에 최적화된 스플래시" 자동 제안.
- 도시 야경 → 네온 사인만 컬러 추천
- 자연 풍경 → 꽃/단풍만 컬러 추천
- 음식 사진 → 주요 재료 색상 추천
VNClassifyImageRequest로 장면 분류 후 규칙 기반 추천.

#### B-10. Selective Desaturation Curve (고급 색상 제어, Pro)
단순 이진(색상 있음/없음) 이 아닌 채도 곡선으로 부분 탈색.
예: 배경의 빨간색을 완전 흑백이 아닌 30% 채도로 남기는 뉘앙스 편집.
Photoshop "Hue/Saturation" 레이어와 유사한 고급 제어.

```swift
// 채도 곡선: 특정 Hue 범위의 채도를 0~100% 사이로 조절
// Metal: per-pixel HSL → S *= saturationCurve(H)
```

#### B-11. One-Shot Style Transfer (AI 스타일 스플래시, Pro)
CoreML 스타일 전이 모델로 컬러 영역에 예술적 스타일 적용.
예:
- 피사체(사람) = 반 고흐 스타일 컬러
- 배경 = 흑백
특정 화가/예술 스타일을 컬러 영역에만 적용하는 독창적 효과.

#### B-12. Focus Sound Design (마이크로 인터랙션)
편집의 각 단계마다 짧은 사운드 디자인 추가.
- AI 분석 완료: 부드러운 "ding"
- 브러시 획: 미세한 붓 소리
- 공유 완료: 만족감 있는 "pop"
청각적 피드백이 앱의 "프리미엄" 느낌을 강화.

---

### 아이디어 우선순위 & Phase 배치

| 아이디어 | 우선순위 | Phase | 플랜 |
|----------|----------|-------|------|
| A-1 Alpha Matting | 최고 | Phase 3 | 무료 |
| A-2 Temporal Smoothing | 최고 | Phase 6 | 무료 |
| A-3 Inverse Mode | 높음 | Phase 5 | 무료 |
| A-4 Depth-Aware Splash | 높음 | Phase 6 | Pro |
| A-5 Smart Palette | 높음 | Phase 3 | 무료 |
| A-6 Haptic Feedback | 높음 | Phase 8 | 무료 |
| A-7 Loop Export | 높음 | Phase 7 | Pro |
| A-8 Hybrid Undo | 높음 | Phase 2 | 무료 |
| A-9 Retina Preview | 높음 | Phase 1 | 무료 |
| A-10 Non-Subject Chip | 중간 | Phase 3 | 무료 |
| B-1 Emotion AI | 중간 | Phase 5 | Pro |
| B-2 Color Story | 중간 | Phase 7 | Pro |
| B-3 Sound-Reactive | 중간 | Phase 7 | Pro |
| B-4 AR Splash | 낮음 | Future | Pro |
| B-5 Community Palette | 낮음 | Future | Pro |
| B-6 Gradient Splash | 중간 | Phase 4 | 무료 |
| B-7 Smart Object Lock | 높음 | Phase 3 | 무료 |
| B-8 Rewind Timelapse | 중간 | Phase 7 | Pro |
| B-9 Contextual Scene | 중간 | Phase 3 | 무료 |
| B-10 Saturation Curve | 낮음 | Future | Pro |
| B-11 Style Transfer | 낮음 | Future | Pro |
| B-12 Sound Design | 중간 | Phase 8 | 무료 |

---

## 17. 개발 일정 로드맵

```
Week 1-2  : Phase 1 ✅ — 기반 구조, 홈 화면, Platform Channel
Week 3-4  : Phase 2 ✅ — 마스크 시스템, 브러시 엔진 (MVP)
Week 5-6  : Phase 3 ✅ — AI 세그멘테이션 (핵심 차별화)
Week 7    : Phase 4 ✅ — Selective Color
Week 8-9  : Phase 5 ✅ — 이펙트 시스템 (바이럴 포인트)
Week 10-11: Phase 6 ✅ — 카메라 모드 (실시간 AI)
Week 12   : Phase 7    — Export, Loop 영상, 공유
Week 13   : Phase 8    — 수익화, 완성도, TestFlight
Week 14   : 버그 수정, 최적화, App Store 제출
```

---

## 18. 완료 체크리스트

> 범례: ✅ 완료 | 🔄 진행 중 | ⬜ 미시작

---

### Phase 1 — 기반 구조 ✅ 완료 (2026-03-17)

- [x] Flutter 프로젝트 폴더 구조 생성
  - `lib/core/`, `lib/features/`, `lib/models/`, `lib/services/` 계층 구조
- [x] pubspec.yaml 패키지 설정
  - flutter_riverpod 2.5.1, go_router 14.x, image_picker 1.1.2, shared_preferences, path_provider, path
- [x] Gen Z 다크 테마 (AppTheme, AppColors, AppSizes, AppStrings)
  - Violet(#7C3AED) + Pink(#EC4899) 그라디언트 브랜드 팔레트
- [x] 홈 화면 UI
  - 그라디언트 앱 이름, 2열 사진 그리드, 빈 상태, 롱프레스 삭제
- [x] 이미지 선택 기능 (갤러리 + 카메라)
  - SharedPreferences에 파일 경로 영속 저장
- [x] iOS Platform Channel 기반 구축
  - `com.colorpop/image` MethodChannel
  - `ImageProcessingChannel.swift` 핸들러
- [x] 기본 흑백 변환 (Core Image GPU, CIColorControls saturation=0)
  - `ColorPopImageProcessor.swift`
- [x] GoRouter 라우팅 (Home ↔ Editor, extra로 EditItem 전달)
- [x] Info.plist 사진/카메라 권한 추가

**생성 파일**: 17개 | **iOS 빌드**: ✅ | **Dart 분석**: 0 issues

---

### Phase 2 — 마스크 & 브러시 ✅ 완료 (2026-03-17)

- [x] Metal 셰이더 3종 (`ColorPopBlend.metal`)
  - `colorPopBlend` — color/gray/mask 합성 커널
  - `paintBrush` — Gaussian falloff 브러시 커널 (영역 최적화 디스패치)
  - `fillMask` — 마스크 전체 초기화 커널
- [x] MaskEngine (Swift + MTLTexture R32Float)
  - 초기화, 스냅샷/복원, fillMask
- [x] BrushEngine (GPU 브러시 페인팅, 브러시 영역만 스레드 디스패치)
- [x] ColorPopBlendRenderer (MTLTexture → JPEG Data)
  - 출력 텍스처 재사용 풀
- [x] EditorSession 싱글톤 (Metal 리소스 세션 관리)
  - initEditor: 이미지 다운스케일(max 1080px) + 컬러/흑백 텍스처 생성 + 초기 렌더링
  - paintBrush / endStroke / undo / redo
- [x] EditHistory — Hybrid Undo/Redo (획 단위 스냅샷, 최대 20단계)
- [x] Platform Channel 메서드 추가
  - `initEditor`, `paintBrush`, `endStroke`, `undoMask`, `redoMask`
- [x] Flutter → Native 터치 좌표 변환
  - 화면 좌표 → BoxFit.contain 보정 → 정규화(0~1) → 네이티브 픽셀
  - 50ms 스로틀링 (브러시 네이티브 호출 ~25fps)
- [x] BrushOverlayPainter (CustomPainter 즉각 시각 피드백)
  - BrushCursorPainter (브러시 커서 원형 표시)
- [x] BrushToolbar UI
  - 크기 슬라이더 (5~150px), 부드러움 슬라이더 (0~100%)
  - Reveal(컬러 살리기) / Erase(흑백으로) 모드 토글
- [x] EditorScreen 업데이트
  - Undo/Redo 버튼 활성/비활성 연동
  - AnimatedSize 브러시 툴바 (브러시 모드 선택 시 슬라이드 등장)
- [x] InteractiveViewer 줌/팬 (브러시 모드에서는 단일 손가락 팬 비활성)
- [x] 단위 테스트 20개 (100% 통과)
  - BrushSettings: 6개 케이스
  - EditItem: 8개 케이스 (직렬화, relativeTime 등)
  - EditorState: 6개 케이스

**생성/수정 파일**: 13개 | **테스트**: 20/20 ✅ | **iOS 빌드**: ✅ | **Dart 분석**: 0 issues

---

### Phase 3 — AI 세그멘테이션 ✅ 완료 (2026-03-17)

- [x] PersonSegmentationEngine (VNGeneratePersonSegmentationRequest)
  - qualityLevel = .accurate, 비동기 async/await 래핑
- [x] Guided Filter 엣지 보정 (CIGaussianBlur radius=1.5 근사)
- [x] 객체 감지 (VNDetectHumanRectanglesRequest + VNDetectFaceRectanglesRequest + VNRecognizeAnimalsRequest)
- [x] 씬 분류 (VNClassifyImageRequest → 하늘 감지, Smart Palette)
- [x] 객체 칩 UI (인물 / 얼굴 / 동물 / 하늘 / 배경 전체)
- [x] "Select All Non-Subject" 칩 (인물 마스크 반전)
- [x] AI 추천 패널 (SmartPaletteEngine: 16×16 그리드 샘플링 + HSL Hue 버킷 → Top3 추천 카드)
- [x] Smart Object Lock 기반 구조 (객체 마스크 캐시 + applyBoundingBoxMask)
- [x] Contextual Scene 분류 (VNClassifyImageRequest)
- [x] AISegmentationChannel.swift (com.colorpop/ai)
  - analyzeImage / applyPersonSegmentation / applyObjectMask / applyNonSubjectMask
- [x] MaskEngine.loadFromFloatArray() (AI 마스크 직접 적용)
- [x] EditorSession Phase 3 확장 (currentImage, applyMaskFromCIImage, applyBoundingBoxMask)
- [x] 공유 CIContext (EditorSession에 lazy var로 재사용)
- [x] Dart 모델: DetectedObject, AiSuggestion
- [x] ai_segmentation_service.dart (com.colorpop/ai 래퍼)
- [x] ai_objects_toolbar.dart (객체 칩 가로 스크롤 + 로딩/빈 상태)
- [x] ai_suggestion_panel.dart (추천 카드 글로우 도트 디자인)
- [x] editor_provider.dart AI 상태 필드 + analyzeImage / applyObjectMask / applySuggestion
- [x] editor_screen.dart AI 탭 활성화 (Phase 3 ✅)
- [x] 관련 테스트 21개 (DetectedObject 7, AiSuggestion 8, EditorState AI 필드 6)

**생성/수정 파일**: 15개 | **테스트**: 41/41 ✅ | **iOS 빌드**: Swift 컴파일 필요

---

### Phase 4 — Selective Color ✅ 완료 (2026-03-17)

- [x] ColorSelectEngine.swift (HSL CPU 샘플링 + Metal colorSelectMask / colorRangeMask 커널)
  - BGRA8Unorm 텍스처 스와이즐 처리 (raw.b=R, raw.g=G, raw.r=B)
  - CPU `rgbToHSL()` 구현 + `samplePixelColor()` (무채색 null 반환)
  - `applyColorSelection()` — 단일 색상 마스크
  - `applyColorRangeSelection()` — 순환 Hue 범위 마스크 (hFrom > hTo 처리)
- [x] ColorPopBlend.metal 확장
  - `rgbToHSL` 헬퍼 함수
  - `colorSelectMask` 커널 (단일 색상)
  - `colorRangeMask` 커널 (그라디언트 범위, 원형 Hue 처리)
- [x] ColorSelection Dart 모델
  - HSL 필드, hexColor → Flutter Color 변환
  - tolerancePercent ↔ tolerance 변환 (0~100% ↔ 0~0.5)
  - copyWith (clearRangeEnd 플래그), equality, toString
- [x] ImageProcessingService 확장
  - samplePixelColor, applyColorSelection, applyColorRangeSelection
- [x] color_picker_toolbar.dart
  - _TapHintBar (빈 상태 힌트)
  - _ActiveBar (색상 원 미리보기 + 범위 모드 토글 + Tolerance 슬라이더)
  - _ColorDot (글로우 원, placeholder '+' 아이콘)
- [x] editor_canvas.dart: _ColorSelectGestureLayer (onTapDown + MouseRegion.precise)
- [x] editor_provider.dart 색상 필드: colorSelection / colorRangeEndSelection / isColorRangeMode / isColorApplying
  - 300ms 디바운스 toleranceTimer
  - sampleAndApplyColor / updateColorTolerance / toggleColorRangeMode / _applyCurrentColorMask
  - setMode() — colorSelect 이탈 시 선택 자동 초기화
- [x] editor_screen.dart 색상 탭 활성화 + ColorPickerToolbar 연결
- [x] 관련 테스트 27개 추가 (ColorSelection 19, EditorState 색상 필드 8)

**생성/수정 파일**: 10개 | **테스트**: 68/68 ✅ | **iOS 빌드**: Swift 컴파일 필요

---

### Phase 5 — 바이럴 이펙트 ✅ 완료 (2026-03-17)

- [x] Metal 커널 5종 (`ColorPopBlend.metal` 확장)
  - `neonGlowEffect` — 컬러 영역 밝기/글로우 부스트
  - `chromaticEffect` — 컬러 영역 RGB 채널 오프셋 (색수차)
  - `filmGrainEffect` — 전체 이미지 해시 노이즈 (프레임 시드 변화)
  - `bgBlurEffect` — 흑백 영역 박스 블러 (radius 최대 5px)
  - `filmNoirEffect` — 흑백 영역 고대비 S커브 + 비네팅
- [x] `BlendParams.isInverse` 추가 → `colorPopBlend` 커널 비파괴 반전 렌더링
- [x] `EffectsEngine.swift` (NEW)
  - 5개 Metal 파이프라인 관리, `apply()` 단일 진입점
  - 출력 텍스처 재사용 풀, 파이프라인 로드 실패 시 graceful degradation
- [x] `ColorPopBlendRenderer.swift` 수정
  - `EffectsEngine` 주입, isInverse + effectType + effectIntensity 파라미터
  - 블렌드 → 이펙트 → JPEG 2패스 파이프라인
- [x] `EditorSession` 수정
  - `currentEffectType`, `currentEffectIntensity`, `isInverseMode` 상태 유지
  - `renderWithCurrentEffects()` 헬퍼 — 모든 렌더 경로에서 이펙트 자동 적용
  - `setEffect(typeString:intensity:)`, `setInverseMode(_:)` 메서드
- [x] Platform Channel: `setEffect`, `setInverseMode` 핸들러 추가
- [x] `EffectConfig` Dart 모델 (EffectType enum + intensity, copyWith, equality)
- [x] `ImageProcessingService` 확장: setEffect, setInverseMode
- [x] `EffectsToolbar` UI
  - 6개 이펙트 칩 (가로 스크롤) + 반전 모드 토글
  - AnimatedSize 강도 슬라이더 (이펙트 선택 시만)
  - 200ms 디바운스 슬라이더, 타입 변경 즉시 적용
- [x] `editor_provider.dart` 이펙트 상태 + setEffectType / updateEffectIntensity / toggleInverseMode
- [x] `editor_screen.dart` 이펙트 탭 활성화 + EffectsToolbar 연결
- [x] 관련 테스트 18개 (EffectConfig 12, EditorState 이펙트 필드 6)

**생성/수정 파일**: 11개 | **테스트**: 86/86 ✅ | **Dart 분석**: 0 errors/warnings

---

### Phase 6 — 카메라 모드 ✅ 완료 (2026-03-17)

- [x] AVFoundation 카메라 세션 (AVCaptureSession, 30fps)
  - `CameraEngine.swift`: 전면/후면 전환, 30fps 고정, BGRA 픽셀 포맷
- [x] 실시간 AI 세그멘테이션 (15fps, 2프레임마다 1회)
  - `Task.detached` 비동기 처리, NSLock 스레드 안전 마스크 전달
- [x] Temporal Smoothing Metal 셰이더 (EMA α=0.3, 지터 방지, A-2)
  - `temporalSmooth` Metal 커널 (ColorPopBlend.metal 추가)
  - ping-pong 텍스처 구조 (rawMask → smooth → prev)
- [x] Metal 추가 커널 2종
  - `makeGrayscale`: BGRA 스와이즐 정확한 루미넌스 계산
  - `realtimeColorSplash`: BGRA I/O 실시간 Color Splash 블렌드
- [x] Flutter Texture Widget 카메라 렌더링
  - `ColorPopCameraTexture` (FlutterTexture 프로토콜, NSLock 보호)
  - `CameraChannel.swift`: `com.colorpop/camera` MethodChannel + FlutterTexture 등록
  - Flutter: `Texture(textureId: id)` 풀스크린 렌더링
- [x] 고해상도 캡처 후 편집기 진입
  - `AVCapturePhotoOutput` → JPEG → 임시 파일 → EditorScreen 이동
- [x] Depth-Aware Splash 기반 구조 (LiDAR 기기, A-4)
  - `CameraEngine.hasLiDAR` 정적 감지 (iOS 15.4+ `builtInLiDARDepthCamera`)
  - Flutter UI: LiDAR 있을 때만 활성 (없으면 30% 투명도로 비활성)
- [x] 반전 모드 토글 (카메라 뷰에서 피사체↔배경 교환)
- [x] AppDelegate 등록 (`CameraChannel.register(with:textureRegistry:)`)
- [x] 홈 화면 카메라 버튼 → `/camera` 라우트 연결
- [x] GoRouter `/camera` 라우트 추가
- [x] `camera_service.dart` (Platform Channel 래퍼)
- [x] `camera_provider.dart` (Riverpod 상태 관리)
- [x] `camera_screen.dart` (풀스크린 카메라 UI)
- [x] 카메라 문자열 상수 (AppStrings)
- [x] 관련 테스트 17개 (CameraState copyWith, 상태 전이, enum, Provider 초기값)

**생성/수정 파일**: 12개 | **테스트**: 103/103 ✅ | **Dart 분석**: 0 errors/warnings

---

### Phase 7 — Export & 공유 ⬜ 미시작

- [ ] 원본 해상도 최종 합성 렌더링 파이프라인
- [ ] JPG/PNG 내보내기 + Photos Framework 저장
- [ ] Loop 영상 자동 생성 (B&W→Color 3~5초, AVAssetWriter, A-7)
- [ ] Before/After 슬라이더 위젯
- [ ] UIActivityViewController 공유
- [ ] 공유 템플릿 (Original|Splash, Before|After)
- [ ] Color Story 멀티프레임 (B-2)
- [ ] 관련 테스트

---

### Phase 8 — 수익화 & 완성 ⬜ 미시작

- [ ] RevenueCat StoreKit 연동
- [ ] 프리미엄 기능 잠금 처리 (AI, 4K, Loop 등)
- [ ] 온보딩 화면 (3단계 튜토리얼)
- [ ] 햅틱 피드백 전체 적용 (엣지 감지 시 진동, A-6)
- [ ] Sound Design 마이크로 인터랙션 (B-12)
- [ ] 성능 프로파일링 (Instruments)
- [ ] TestFlight 배포
- [ ] App Store 제출 준비

---

## 19. 구현 현황 요약

| Phase | 상태 | 핵심 구현 | 파일 수 | 테스트 |
|-------|------|-----------|---------|--------|
| Phase 1 — 기반 구조 | ✅ 완료 | 홈UI, 갤러리, Platform Channel, 흑백변환 | 17개 | 빌드 검증 |
| Phase 2 — 마스크/브러시 | ✅ 완료 | Metal 셰이더, MaskEngine, BrushEngine, Undo/Redo | 13개 | 20/20 ✅ |
| Phase 3 — AI 세그멘테이션 | ✅ 완료 | VNPersonSegmentation, ObjectDetection, SmartPalette, 객체칩/추천카드 | 15개 | 41/41 ✅ |
| Phase 4 — 색상 선택 | ✅ 완료 | HSL Metal 셰이더, Tap-to-Color, Tolerance 슬라이더, 그라디언트 범위(B-6) | 10개 | 68/68 ✅ |
| Phase 5 — 이펙트 | ✅ 완료 | Neon Glow, Chromatic, Film Grain, BG Blur, Film Noir, Inverse Mode | 11개 | 86/86 ✅ |
| Phase 6 — 카메라 | ✅ 완료 | AVFoundation 30fps, 실시간 AI 15fps, Temporal Smoothing, FlutterTexture, LiDAR 감지 | 12개 | 103/103 ✅ |
| Phase 7 — Export | ⬜ 미시작 | 고해상도 렌더링, Loop 영상, 공유 | — | — |
| Phase 8 — 완성 | ⬜ 미시작 | RevenueCat, 온보딩, 햅틱, TestFlight | — | — |

**전체 진행률**: 6 / 8 Phase 완료 (75%)

---

*process.md — ColorPop 상세 구현 계획서 v1.6.0*
*작성: 2026-03-17 | 업데이트: 2026-03-17 (Phase 6 카메라 모드 구현 완료)*
