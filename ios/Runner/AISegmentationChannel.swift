import Flutter
import Metal
import UIKit

/// AI 세그멘테이션 Platform Channel
/// Flutter ↔ Swift AI 통신을 담당한다 (com.colorpop/ai)
class AISegmentationChannel {
    static let channelName = "com.colorpop/ai"

    // AI 엔진 (한 번만 초기화)
    private static let device: MTLDevice = MTLCreateSystemDefaultDevice()!
    private static let personEngine = PersonSegmentationEngine()
    private static let objectEngine = ObjectDetectionEngine()
    private static let paletteEngine = SmartPaletteEngine(device: MTLCreateSystemDefaultDevice()!)

    // 분석 결과 캐시
    private static var cachedObjects: [DetectedObjectInfo] = []
    private static var cachedPersonMask: CIImage?

    // MARK: - 채널 등록

    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)

        channel.setMethodCallHandler { call, result in
            switch call.method {

            // ── 이미지 전체 AI 분석 ──────────────────────────────────
            // 반환: { objects: [...], suggestions: [...] }
            case "analyzeImage":
                guard let image = ImageProcessingChannel.session?.currentImage else {
                    result(FlutterError(code: "NO_SESSION", message: "세션 없음", details: nil))
                    return
                }
                Task {
                    let objects = await objectEngine.detectObjects(from: image)
                    let sceneLabels = objectEngine.classifyScene(from: image)
                    cachedObjects = objects
                    cachedPersonMask = nil  // 새 이미지이므로 캐시 초기화

                    let suggestions = paletteEngine.generateSuggestions(
                        from: image,
                        detectedObjects: objects,
                        sceneLabels: sceneLabels
                    )

                    await MainActor.run {
                        let objMaps: [[String: Any]] = objects.map { obj in
                            [
                                "label": obj.label,
                                "korLabel": obj.korLabel,
                                "confidence": Double(obj.confidence),
                                "x": Double(obj.boundingBox.origin.x),
                                "y": Double(obj.boundingBox.origin.y),
                                "w": Double(obj.boundingBox.width),
                                "h": Double(obj.boundingBox.height),
                                "maskType": obj.maskType.rawValue,
                            ]
                        }
                        let suggMaps: [[String: Any]] = suggestions.map { s in
                            [
                                "id": s.id,
                                "title": s.title,
                                "description": s.description,
                                "maskLabel": s.maskLabel,
                                "colorHex": s.colorHex,
                            ]
                        }
                        result(["objects": objMaps, "suggestions": suggMaps])
                    }
                }

            // ── 인물 세그멘테이션 적용 ───────────────────────────────
            // 반환: JPEG Data (렌더링된 프레임)
            case "applyPersonSegmentation":
                guard let image = ImageProcessingChannel.session?.currentImage else {
                    result(FlutterError(code: "NO_SESSION", message: "세션 없음", details: nil))
                    return
                }
                Task {
                    let mask: CIImage?
                    if let cached = cachedPersonMask {
                        mask = cached
                    } else {
                        mask = await personEngine.segmentPerson(from: image)
                        cachedPersonMask = mask
                    }

                    guard let personMask = mask else {
                        await MainActor.run {
                            result(FlutterError(code: "SEG_FAILED", message: "세그멘테이션 실패", details: nil))
                        }
                        return
                    }

                    let frame = ImageProcessingChannel.session?.applyMaskFromCIImage(personMask)
                    await MainActor.run {
                        frame != nil
                            ? result(FlutterStandardTypedData(bytes: frame!))
                            : result(FlutterError(code: "RENDER_ERROR", message: "렌더링 실패", details: nil))
                    }
                }

            // ── 특정 객체 마스크 적용 ────────────────────────────────
            // 인자: { "label": String }
            // 반환: JPEG Data
            case "applyObjectMask":
                guard
                    let args = call.arguments as? [String: Any],
                    let label = args["label"] as? String,
                    let session = ImageProcessingChannel.session
                else {
                    result(FlutterError(code: "INVALID_ARGS", message: "label 필요", details: nil))
                    return
                }
                Task {
                    let frame = await applyObjectMask(label: label, session: session)
                    await MainActor.run {
                        frame != nil
                            ? result(FlutterStandardTypedData(bytes: frame!))
                            : result(FlutterError(code: "MASK_ERROR", message: "마스크 적용 실패", details: nil))
                    }
                }

            // ── 비-피사체 전체 선택 (인물 마스크 반전) ──────────────
            // 반환: JPEG Data
            case "applyNonSubjectMask":
                guard let image = ImageProcessingChannel.session?.currentImage else {
                    result(FlutterError(code: "NO_SESSION", message: "세션 없음", details: nil))
                    return
                }
                Task {
                    var pm = cachedPersonMask
                    if pm == nil {
                        pm = await personEngine.segmentPerson(from: image)
                        cachedPersonMask = pm
                    }
                    guard let personMask = pm else {
                        await MainActor.run {
                            result(FlutterError(code: "SEG_FAILED", message: "세그멘테이션 실패", details: nil))
                        }
                        return
                    }

                    // 반전: 인물(0=컬러) → 배경(0=컬러)
                    let inverted = PersonSegmentationEngine.invertMask(personMask) ?? personMask
                    let frame = ImageProcessingChannel.session?.applyMaskFromCIImage(inverted)
                    await MainActor.run {
                        frame != nil
                            ? result(FlutterStandardTypedData(bytes: frame!))
                            : result(FlutterError(code: "RENDER_ERROR", message: "렌더링 실패", details: nil))
                    }
                }

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    // MARK: - 객체 마스크 적용 로직

    private static func applyObjectMask(label: String, session: EditorSession) async -> Data? {
        guard let obj = cachedObjects.first(where: { $0.label == label }),
              let image = session.currentImage
        else { return nil }

        switch obj.maskType {
        case .person:
            // 인물 세그멘테이션 마스크 사용
            var pm = cachedPersonMask
            if pm == nil {
                pm = await personEngine.segmentPerson(from: image)
                cachedPersonMask = pm
            }
            guard let mask = pm else { return nil }
            return session.applyMaskFromCIImage(mask)

        case .boundingBox, .topRegion:
            // 바운딩 박스 기반 마스크
            return session.applyBoundingBoxMask(boundingBox: obj.boundingBox)

        case .inverted:
            // 인물 마스크 반전 (배경 전체)
            var pm = cachedPersonMask
            if pm == nil {
                pm = await personEngine.segmentPerson(from: image)
                cachedPersonMask = pm
            }
            guard let mask = pm else { return nil }
            let inverted = PersonSegmentationEngine.invertMask(mask) ?? mask
            return session.applyMaskFromCIImage(inverted)
        }
    }
}
