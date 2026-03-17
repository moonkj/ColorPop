import Flutter
import Metal
import MetalKit
import CoreImage
import UIKit

/// ColorPop 이미지 처리 Platform Channel
/// Flutter ↔ Swift 통신을 담당한다
class ImageProcessingChannel {
    static let channelName = "com.colorpop/image"

    // 현재 편집 세션 (AISegmentationChannel에서도 접근)
    static var session: EditorSession?

    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)

        channel.setMethodCallHandler { call, result in
            switch call.method {

            // ── Phase 1: 흑백 변환 ─────────────────────────────
            case "processGrayscale":
                guard
                    let args = call.arguments as? [String: Any],
                    let imageData = (args["imageData"] as? FlutterStandardTypedData)?.data
                else {
                    result(FlutterError(code: "INVALID_ARGS", message: "imageData 필요", details: nil))
                    return
                }
                DispatchQueue.global(qos: .userInitiated).async {
                    let processed = ColorPopImageProcessor.convertToGrayscale(imageData: imageData)
                    DispatchQueue.main.async {
                        processed != nil
                            ? result(FlutterStandardTypedData(bytes: processed!))
                            : result(FlutterError(code: "PROCESS_ERROR", message: "흑백 변환 실패", details: nil))
                    }
                }

            // ── Phase 2: 편집 세션 초기화 ────────────────────────
            case "initEditor":
                guard
                    let args = call.arguments as? [String: Any],
                    let imageData = (args["imageData"] as? FlutterStandardTypedData)?.data
                else {
                    result(FlutterError(code: "INVALID_ARGS", message: "imageData 필요", details: nil))
                    return
                }
                DispatchQueue.global(qos: .userInitiated).async {
                    let newSession = EditorSession()
                    let initResult = newSession.initialize(imageData: imageData)
                    DispatchQueue.main.async {
                        if let res = initResult {
                            session = newSession
                            result(res)
                        } else {
                            result(FlutterError(code: "INIT_ERROR", message: "세션 초기화 실패", details: nil))
                        }
                    }
                }

            // ── Phase 2: 브러시 페인팅 ──────────────────────────
            case "paintBrush":
                guard
                    let args = call.arguments as? [String: Any],
                    let s = session
                else {
                    result(FlutterError(code: "NO_SESSION", message: "세션 없음", details: nil))
                    return
                }
                let x         = (args["x"] as? Double).map { Float($0) } ?? 0.5
                let y         = (args["y"] as? Double).map { Float($0) } ?? 0.5
                let size      = (args["size"] as? Double).map { Float($0) } ?? 40.0
                let softness  = (args["softness"] as? Double).map { Float($0) } ?? 0.5
                let opacity   = (args["opacity"] as? Double).map { Float($0) } ?? 1.0
                let isReveal  = args["isReveal"] as? Bool ?? true

                DispatchQueue.global(qos: .userInteractive).async {
                    let frame = s.paintBrush(
                        x: x, y: y,
                        size: size, softness: softness,
                        opacity: opacity, isReveal: isReveal
                    )
                    DispatchQueue.main.async {
                        frame != nil
                            ? result(FlutterStandardTypedData(bytes: frame!))
                            : result(FlutterError(code: "PAINT_ERROR", message: "브러시 페인팅 실패", details: nil))
                    }
                }

            // ── Phase 2: 획 종료 (Undo 스냅샷 저장) ─────────────
            case "endStroke":
                session?.saveUndoSnapshot()
                result(nil)

            // ── Phase 2: Undo ────────────────────────────────────
            case "undoMask":
                guard let s = session else {
                    result(FlutterError(code: "NO_SESSION", message: "세션 없음", details: nil))
                    return
                }
                DispatchQueue.global(qos: .userInitiated).async {
                    let frame = s.undo()
                    DispatchQueue.main.async {
                        frame != nil
                            ? result(FlutterStandardTypedData(bytes: frame!))
                            : result(FlutterError(code: "UNDO_ERROR", message: "Undo 불가", details: nil))
                    }
                }

            // ── Phase 4: 픽셀 색상 샘플링 ───────────────────────────
            case "samplePixelColor":
                guard
                    let args = call.arguments as? [String: Any],
                    let s = session
                else {
                    result(FlutterError(code: "NO_SESSION", message: "세션 없음", details: nil))
                    return
                }
                let nx = (args["x"] as? Double).map { Float($0) } ?? 0.5
                let ny = (args["y"] as? Double).map { Float($0) } ?? 0.5
                DispatchQueue.global(qos: .userInteractive).async {
                    let sampled = s.samplePixelColor(normalizedX: nx, normalizedY: ny)
                    DispatchQueue.main.async {
                        if let sc = sampled {
                            result([
                                "h": Double(sc.h),
                                "s": Double(sc.s),
                                "l": Double(sc.l),
                                "hexColor": sc.hexColor,
                                "isGrayscale": sc.isGrayscale,
                            ])
                        } else {
                            result(FlutterError(code: "SAMPLE_ERROR", message: "픽셀 샘플링 실패", details: nil))
                        }
                    }
                }

            // ── Phase 4: 색상 선택 마스크 적용 ──────────────────────
            case "applyColorSelection":
                guard
                    let args = call.arguments as? [String: Any],
                    let s = session
                else {
                    result(FlutterError(code: "NO_SESSION", message: "세션 없음", details: nil))
                    return
                }
                let targetH   = (args["h"]         as? Double).map { Float($0) } ?? 0.0
                let targetS   = (args["s"]         as? Double).map { Float($0) } ?? 0.0
                let tolerance = (args["tolerance"] as? Double).map { Float($0) } ?? 0.1
                DispatchQueue.global(qos: .userInitiated).async {
                    let frame = s.applyColorSelection(h: targetH, s: targetS, tolerance: tolerance)
                    DispatchQueue.main.async {
                        frame != nil
                            ? result(FlutterStandardTypedData(bytes: frame!))
                            : result(FlutterError(code: "COLOR_ERROR", message: "색상 마스크 적용 실패", details: nil))
                    }
                }

            // ── Phase 4: 그라디언트 범위 색상 선택 (B-6) ────────────
            case "applyColorRangeSelection":
                guard
                    let args = call.arguments as? [String: Any],
                    let s = session
                else {
                    result(FlutterError(code: "NO_SESSION", message: "세션 없음", details: nil))
                    return
                }
                let hFrom     = (args["hFrom"]     as? Double).map { Float($0) } ?? 0.0
                let hTo       = (args["hTo"]       as? Double).map { Float($0) } ?? 0.1
                let rangeTol  = (args["tolerance"] as? Double).map { Float($0) } ?? 0.05
                DispatchQueue.global(qos: .userInitiated).async {
                    let frame = s.applyColorRangeSelection(hFrom: hFrom, hTo: hTo, tolerance: rangeTol)
                    DispatchQueue.main.async {
                        frame != nil
                            ? result(FlutterStandardTypedData(bytes: frame!))
                            : result(FlutterError(code: "RANGE_ERROR", message: "범위 색상 마스크 적용 실패", details: nil))
                    }
                }

            // ── Phase 2: Redo ────────────────────────────────────
            case "redoMask":
                guard let s = session else {
                    result(FlutterError(code: "NO_SESSION", message: "세션 없음", details: nil))
                    return
                }
                DispatchQueue.global(qos: .userInitiated).async {
                    let frame = s.redo()
                    DispatchQueue.main.async {
                        frame != nil
                            ? result(FlutterStandardTypedData(bytes: frame!))
                            : result(FlutterError(code: "REDO_ERROR", message: "Redo 불가", details: nil))
                    }
                }

            // ── Phase 5: 이펙트 설정 ──────────────────────────────
            case "setEffect":
                guard
                    let args = call.arguments as? [String: Any],
                    let s = session
                else {
                    result(FlutterError(code: "NO_SESSION", message: "세션 없음", details: nil))
                    return
                }
                let effectTypeStr = args["effectType"] as? String ?? "none"
                let effectIntensity = (args["intensity"] as? Double).map { Float($0) } ?? 0.5
                DispatchQueue.global(qos: .userInitiated).async {
                    let frame = s.setEffect(typeString: effectTypeStr, intensity: effectIntensity)
                    DispatchQueue.main.async {
                        frame != nil
                            ? result(FlutterStandardTypedData(bytes: frame!))
                            : result(FlutterError(code: "EFFECT_ERROR", message: "이펙트 적용 실패", details: nil))
                    }
                }

            // ── Phase 5: 반전 모드 ────────────────────────────────
            case "setInverseMode":
                guard
                    let args = call.arguments as? [String: Any],
                    let s = session
                else {
                    result(FlutterError(code: "NO_SESSION", message: "세션 없음", details: nil))
                    return
                }
                let isInv = args["isInverse"] as? Bool ?? false
                DispatchQueue.global(qos: .userInitiated).async {
                    let frame = s.setInverseMode(isInv)
                    DispatchQueue.main.async {
                        frame != nil
                            ? result(FlutterStandardTypedData(bytes: frame!))
                            : result(FlutterError(code: "INVERSE_ERROR", message: "반전 모드 적용 실패", details: nil))
                    }
                }

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}

// ── 편집 세션 ─────────────────────────────────────────────────
/// 하나의 이미지 편집에 필요한 Metal 리소스를 관리
class EditorSession {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var colorTexture: MTLTexture?
    private var grayTexture: MTLTexture?
    private var maskEngine: MaskEngine
    private var brushEngine: BrushEngine
    private var renderer: ColorPopBlendRenderer
    private let history = EditHistory()
    private var colorSelectEngine: ColorSelectEngine

    // Phase 5: 현재 이펙트 상태
    private var currentEffectType: EffectsEngine.EffectType = .none
    private var currentEffectIntensity: Float = 0.5
    private var isInverseMode: Bool = false

    private(set) var currentImage: UIImage?

    private lazy var ciContext: CIContext = CIContext(
        mtlDevice: device, options: [.useSoftwareRenderer: false]
    )

    init() {
        guard let dev = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal 미지원 기기")
        }
        self.device = dev
        self.commandQueue = dev.makeCommandQueue()!
        self.maskEngine = MaskEngine(device: dev)
        self.brushEngine = BrushEngine(device: dev, commandQueue: dev.makeCommandQueue()!)
        let effectsEngine = EffectsEngine(device: dev, commandQueue: dev.makeCommandQueue()!)
        self.renderer = ColorPopBlendRenderer(
            device: dev,
            commandQueue: dev.makeCommandQueue()!,
            effectsEngine: effectsEngine
        )
        self.colorSelectEngine = ColorSelectEngine(device: dev, commandQueue: dev.makeCommandQueue()!)
    }

    /// 현재 이펙트 + 반전 모드로 렌더링
    private func renderWithCurrentEffects() -> Data? {
        guard
            let color = colorTexture,
            let gray  = grayTexture,
            let mask  = maskEngine.maskTexture
        else { return nil }
        return renderer.render(
            colorTexture:    color,
            grayTexture:     gray,
            maskTexture:     mask,
            effectType:      currentEffectType,
            effectIntensity: currentEffectIntensity,
            isInverse:       isInverseMode
        )
    }

    /// 세션 초기화: 이미지 로드, 텍스처 생성, 초기 렌더링
    /// 반환: {"frame": Data, "width": Int, "height": Int}
    func initialize(imageData: Data) -> [String: Any]? {
        guard let uiImage = UIImage(data: imageData) else { return nil }

        // 편집 프리뷰용으로 다운스케일 (최대 1080px 긴 변)
        let scaledImage = uiImage.scaledToMaxDimension(1080)
        currentImage = scaledImage
        guard let cgImage = scaledImage.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height

        // 컬러 텍스처 생성
        colorTexture = makeCGImageTexture(cgImage, device: device)

        // 흑백 텍스처 생성 (Core Image CIColorControls)
        grayTexture = makeGrayscaleTexture(scaledImage, device: device)

        guard colorTexture != nil, grayTexture != nil else { return nil }

        // 마스크 초기화 (전체 1.0 = 흑백)
        maskEngine.initialize(imageSize: CGSize(width: width, height: height))

        // 초기 렌더링 (전체 흑백 상태)
        guard
            let frame = renderer.render(
                colorTexture: colorTexture!,
                grayTexture: grayTexture!,
                maskTexture: maskEngine.maskTexture!
            )
        else { return nil }

        // 초기 스냅샷 저장 (Undo 기점)
        if let snapshot = maskEngine.takeSnapshot() {
            history.reset()
            history.push(snapshot)
        }

        return [
            "frame": FlutterStandardTypedData(bytes: frame),
            "width": width,
            "height": height,
        ]
    }

    /// 브러시 페인팅 + 렌더링
    func paintBrush(
        x: Float, y: Float,
        size: Float, softness: Float,
        opacity: Float, isReveal: Bool
    ) -> Data? {
        guard let mask = maskEngine.maskTexture else { return nil }
        brushEngine.paint(
            on: mask,
            normalizedX: x, normalizedY: y,
            size: size, softness: softness,
            opacity: opacity, isReveal: isReveal
        )
        return renderWithCurrentEffects()
    }

    /// 획 종료 시 Undo 스냅샷 저장
    func saveUndoSnapshot() {
        guard let snapshot = maskEngine.takeSnapshot() else { return }
        history.push(snapshot)
    }

    func undo() -> Data? {
        guard let snapshot = history.undo() else { return nil }
        return restoreAndRender(snapshot)
    }

    func redo() -> Data? {
        guard let snapshot = history.redo() else { return nil }
        return restoreAndRender(snapshot)
    }

    // ── Phase 5: 이펙트 ──────────────────────────────────────────

    /// 이펙트 타입 + 강도 설정 후 재렌더링
    func setEffect(typeString: String, intensity: Float) -> Data? {
        currentEffectType = EffectsEngine.EffectType.from(typeString)
        currentEffectIntensity = intensity
        return renderWithCurrentEffects()
    }

    /// 반전 모드 설정 후 재렌더링
    func setInverseMode(_ isInverse: Bool) -> Data? {
        isInverseMode = isInverse
        return renderWithCurrentEffects()
    }

    // ── Phase 4: 색상 선택 ───────────────────────────────────────

    /// 정규화 좌표에서 픽셀 색상을 추출한다
    func samplePixelColor(normalizedX: Float, normalizedY: Float) -> ColorSelectEngine.SampledColor? {
        guard let colorTex = colorTexture else { return nil }
        return colorSelectEngine.samplePixelColor(
            from: colorTex,
            normalizedX: normalizedX,
            normalizedY: normalizedY
        )
    }

    func applyColorSelection(h: Float, s: Float, tolerance: Float) -> Data? {
        guard
            let colorTex = colorTexture,
            let maskTex  = maskEngine.maskTexture
        else { return nil }
        colorSelectEngine.applyColorSelection(
            colorTexture: colorTex, maskTexture: maskTex,
            targetH: h, targetS: s, hueTolerance: tolerance
        )
        if let snapshot = maskEngine.takeSnapshot() { history.push(snapshot) }
        return renderWithCurrentEffects()
    }

    func applyColorRangeSelection(hFrom: Float, hTo: Float, tolerance: Float) -> Data? {
        guard
            let colorTex = colorTexture,
            let maskTex  = maskEngine.maskTexture
        else { return nil }
        colorSelectEngine.applyColorRangeSelection(
            colorTexture: colorTex, maskTexture: maskTex,
            hFrom: hFrom, hTo: hTo, hueTolerance: tolerance
        )
        if let snapshot = maskEngine.takeSnapshot() { history.push(snapshot) }
        return renderWithCurrentEffects()
    }

    // ── Phase 3: AI 마스크 적용 ──────────────────────────────────

    /// CIImage 마스크를 maskTexture에 적용하고 렌더링 결과를 반환한다
    func applyMaskFromCIImage(_ maskCI: CIImage) -> Data? {
        guard
            let mask = maskEngine.maskTexture,
            let color = colorTexture,
            let gray = grayTexture
        else { return nil }

        let width = mask.width
        let height = mask.height

        // CIImage를 이미지 크기에 맞게 스케일
        let maskExtent = maskCI.extent
        let scaleX = CGFloat(width) / maskExtent.width
        let scaleY = CGFloat(height) / maskExtent.height
        let scaledMask = maskCI.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        // RGBA8 비트맵으로 렌더링 후 R 채널을 Float32로 변환
        var bitmap = [UInt8](repeating: 0, count: width * height * 4)
        ciContext.render(
            scaledMask,
            toBitmap: &bitmap,
            rowBytes: width * 4,
            bounds: CGRect(x: 0, y: 0, width: width, height: height),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        var floatData = (0..<(width * height)).map { Float(bitmap[$0 * 4]) / 255.0 }
        maskEngine.loadFromFloatArray(floatData)

        // Undo 스냅샷 저장
        if let snapshot = maskEngine.takeSnapshot() { history.push(snapshot) }
        return renderWithCurrentEffects()
    }

    /// 바운딩 박스 영역을 컬러로 선택한다 (Vision 좌표계 → Metal 좌표계 변환 포함)
    /// - Parameters:
    ///   - boundingBox: Vision 정규화 좌표 (원점=좌하단)
    ///   - fillValue: 채울 값 (0.0=컬러, 1.0=흑백)
    func applyBoundingBoxMask(boundingBox: CGRect, fillValue: Float = 0.0) -> Data? {
        guard
            let mask = maskEngine.maskTexture,
            let color = colorTexture,
            let gray = grayTexture
        else { return nil }

        let w = mask.width
        let h = mask.height

        // 마스크 전체를 흑백(1.0)으로 초기화
        maskEngine.fillMask(value: 1.0)

        // Vision 좌표계(좌하단 원점) → Metal 좌표계(좌상단 원점) 변환
        let pixX = Int(boundingBox.origin.x * CGFloat(w))
        let pixW = Int(boundingBox.width * CGFloat(w))
        let flippedY = 1.0 - boundingBox.origin.y - boundingBox.height
        let pixY = Int(flippedY * CGFloat(h))
        let pixH = Int(boundingBox.height * CGFloat(h))

        let safeX = max(0, min(pixX, w - 1))
        let safeY = max(0, min(pixY, h - 1))
        let safeW = max(1, min(pixW, w - safeX))
        let safeH = max(1, min(pixH, h - safeY))

        let rowData = [Float](repeating: fillValue, count: safeW)
        rowData.withUnsafeBytes { ptr in
            for row in safeY..<(safeY + safeH) {
                mask.replace(
                    region: MTLRegionMake2D(safeX, row, safeW, 1),
                    mipmapLevel: 0,
                    withBytes: ptr.baseAddress!,
                    bytesPerRow: safeW * MemoryLayout<Float>.size
                )
            }
        }

        if let snapshot = maskEngine.takeSnapshot() { history.push(snapshot) }
        return renderWithCurrentEffects()
    }

    // ─────────────────────────────────────────────────────────────

    private func restoreAndRender(_ snapshot: Data) -> Data? {
        maskEngine.restoreSnapshot(snapshot)
        return renderWithCurrentEffects()
    }

    // ── 텍스처 유틸 ─────────────────────────────────────────
    private func makeCGImageTexture(_ cgImage: CGImage, device: MTLDevice) -> MTLTexture? {
        let loader = MTKTextureLoader(device: device)
        return try? loader.newTexture(cgImage: cgImage, options: [
            .textureUsage: MTLTextureUsage([.shaderRead, .shaderWrite]).rawValue as NSNumber,
            .textureStorageMode: MTLStorageMode.shared.rawValue as NSNumber,
            .SRGB: false as NSNumber,
        ])
    }

    private func makeGrayscaleTexture(_ image: UIImage, device: MTLDevice) -> MTLTexture? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let filter = CIFilter(name: "CIColorControls")!
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(0.0, forKey: kCIInputSaturationKey)
        filter.setValue(1.05, forKey: kCIInputBrightnessKey)
        filter.setValue(1.1, forKey: kCIInputContrastKey)

        guard let output = filter.outputImage else { return nil }

        let context = CIContext(mtlDevice: device, options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(output, from: output.extent) else { return nil }
        return makeCGImageTexture(cgImage, device: device)
    }
}

// ── UIImage 확장: 다운스케일 ────────────────────────────────────
private extension UIImage {
    func scaledToMaxDimension(_ maxDim: CGFloat) -> UIImage {
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDim else { return self }
        let scale = maxDim / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
