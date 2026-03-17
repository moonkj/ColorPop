import Metal
import simd
import UIKit

/// HSL 색공간 기반 색상 선택 엔진
/// Metal GPU 커널로 colorSelectMask / colorRangeMask를 실행한다
class ColorSelectEngine {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var selectPipeline: MTLComputePipelineState?  // colorSelectMask
    private var rangePipeline: MTLComputePipelineState?   // colorRangeMask

    // Metal 셰이더 params 구조체 (colorSelectMask)
    struct ColorSelectParams {
        var targetH: Float
        var targetS: Float
        var hueTol:  Float
        var satMin:  Float
    }

    // Metal 셰이더 params 구조체 (colorRangeMask)
    struct ColorRangeParams {
        var hFrom:  Float
        var hTo:    Float
        var hueTol: Float
        var satMin: Float
    }

    // HSL 색상 정보 (CPU 샘플링 결과)
    struct SampledColor {
        let r: Float
        let g: Float
        let b: Float
        let h: Float  // 0~1
        let s: Float  // 0~1
        let l: Float  // 0~1
        let hexColor: String  // "#RRGGBB"

        /// 채도가 너무 낮아 색상 선택이 의미 없는지 확인
        var isGrayscale: Bool { s < 0.08 }
    }

    init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        self.device = device
        self.commandQueue = commandQueue
        setupPipelines()
    }

    private func setupPipelines() {
        guard let library = device.makeDefaultLibrary() else {
            print("[ColorSelectEngine] Metal library 로드 실패")
            return
        }
        if let fn = library.makeFunction(name: "colorSelectMask") {
            selectPipeline = try? device.makeComputePipelineState(function: fn)
        }
        if let fn = library.makeFunction(name: "colorRangeMask") {
            rangePipeline = try? device.makeComputePipelineState(function: fn)
        }
    }

    // MARK: - 픽셀 샘플링

    /// 정규화 좌표에서 픽셀 색상을 추출한다
    /// colorTexture 포맷: BGRA8Unorm (MTKTextureLoader iOS 기본)
    func samplePixelColor(
        from colorTexture: MTLTexture,
        normalizedX: Float,
        normalizedY: Float
    ) -> SampledColor? {
        let pixX = max(0, min(Int(normalizedX * Float(colorTexture.width)),  colorTexture.width  - 1))
        let pixY = max(0, min(Int(normalizedY * Float(colorTexture.height)), colorTexture.height - 1))

        var bytes = [UInt8](repeating: 0, count: 4)
        colorTexture.getBytes(
            &bytes,
            bytesPerRow: 4,
            from: MTLRegionMake2D(pixX, pixY, 1, 1),
            mipmapLevel: 0
        )

        // BGRA8Unorm: [0]=B, [1]=G, [2]=R, [3]=A
        let r: Float
        let g: Float
        let b: Float
        switch colorTexture.pixelFormat {
        case .bgra8Unorm, .bgra8Unorm_srgb:
            b = Float(bytes[0]) / 255.0
            g = Float(bytes[1]) / 255.0
            r = Float(bytes[2]) / 255.0
        case .rgba8Unorm, .rgba8Unorm_srgb:
            r = Float(bytes[0]) / 255.0
            g = Float(bytes[1]) / 255.0
            b = Float(bytes[2]) / 255.0
        default:
            // 알 수 없는 포맷이면 BGRA로 시도
            b = Float(bytes[0]) / 255.0
            g = Float(bytes[1]) / 255.0
            r = Float(bytes[2]) / 255.0
        }

        let (h, s, l) = rgbToHSL(r: r, g: g, b: b)
        let hex = String(
            format: "#%02X%02X%02X",
            Int(r * 255), Int(g * 255), Int(b * 255)
        )
        return SampledColor(r: r, g: g, b: b, h: h, s: s, l: l, hexColor: hex)
    }

    // MARK: - 단일 색상 마스크 적용

    /// targetH 기준으로 ±hueTolerance 범위의 색상을 컬러로 선택한다
    func applyColorSelection(
        colorTexture: MTLTexture,
        maskTexture: MTLTexture,
        targetH: Float,
        targetS: Float,
        hueTolerance: Float
    ) {
        guard
            let pipeline = selectPipeline,
            let cmdBuf = commandQueue.makeCommandBuffer(),
            let encoder = cmdBuf.makeComputeCommandEncoder()
        else { return }

        var params = ColorSelectParams(
            targetH: targetH,
            targetS: targetS,
            hueTol:  hueTolerance,
            satMin:  0.08
        )

        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(colorTexture, index: 0)
        encoder.setTexture(maskTexture,  index: 1)
        encoder.setBytes(&params, length: MemoryLayout<ColorSelectParams>.stride, index: 0)

        let threads = MTLSize(width: 16, height: 16, depth: 1)
        let groups  = MTLSize(
            width:  (colorTexture.width  + 15) / 16,
            height: (colorTexture.height + 15) / 16,
            depth: 1
        )
        encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: threads)
        encoder.endEncoding()
        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()
    }

    // MARK: - 그라디언트 범위 마스크 적용 (B-6)

    /// [hFrom, hTo] Hue 범위의 색상을 컬러로 선택한다
    func applyColorRangeSelection(
        colorTexture: MTLTexture,
        maskTexture: MTLTexture,
        hFrom: Float,
        hTo: Float,
        hueTolerance: Float
    ) {
        guard
            let pipeline = rangePipeline,
            let cmdBuf = commandQueue.makeCommandBuffer(),
            let encoder = cmdBuf.makeComputeCommandEncoder()
        else { return }

        var params = ColorRangeParams(
            hFrom:  hFrom,
            hTo:    hTo,
            hueTol: hueTolerance,
            satMin: 0.08
        )

        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(colorTexture, index: 0)
        encoder.setTexture(maskTexture,  index: 1)
        encoder.setBytes(&params, length: MemoryLayout<ColorRangeParams>.stride, index: 0)

        let threads = MTLSize(width: 16, height: 16, depth: 1)
        let groups  = MTLSize(
            width:  (colorTexture.width  + 15) / 16,
            height: (colorTexture.height + 15) / 16,
            depth: 1
        )
        encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: threads)
        encoder.endEncoding()
        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()
    }

    // MARK: - HSL 변환 (CPU)

    private func rgbToHSL(r: Float, g: Float, b: Float) -> (h: Float, s: Float, l: Float) {
        let maxC = max(r, max(g, b))
        let minC = min(r, min(g, b))
        let l    = (maxC + minC) / 2.0

        guard maxC != minC else { return (0, 0, l) }

        let d = maxC - minC
        let s = l > 0.5 ? d / (2.0 - maxC - minC) : d / (maxC + minC)

        let h: Float
        if      maxC == r { h = ((g - b) / d + (g < b ? 6.0 : 0.0)) / 6.0 }
        else if maxC == g { h = ((b - r) / d + 2.0) / 6.0 }
        else              { h = ((r - g) / d + 4.0) / 6.0 }

        return (h, s, l)
    }
}
