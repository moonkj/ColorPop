import Metal
import simd

/// Metal Compute Shader 기반 브러시 페인팅 엔진
class BrushEngine {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var brushPipeline: MTLComputePipelineState?

    // BrushParams은 Metal 셰이더의 struct와 메모리 레이아웃이 동일해야 함
    struct BrushParams {
        var center: SIMD2<Float>
        var radius: Float
        var softness: Float
        var opacity: Float
        var targetValue: Float   // 0=컬러, 1=흑백
    }

    init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        self.device = device
        self.commandQueue = commandQueue
        setupPipeline()
    }

    private func setupPipeline() {
        guard
            let library = device.makeDefaultLibrary(),
            let fn = library.makeFunction(name: "paintBrush")
        else {
            print("[BrushEngine] paintBrush 함수 로드 실패")
            return
        }
        brushPipeline = try? device.makeComputePipelineState(function: fn)
    }

    /// 브러시 한 점 페인팅
    /// - Parameters:
    ///   - maskTexture: 수정할 마스크 텍스처
    ///   - normalizedX: 정규화 X (0~1)
    ///   - normalizedY: 정규화 Y (0~1)
    ///   - size: 브러시 크기 (0~150, 이미지 픽셀 기준)
    ///   - softness: 0.0~1.0
    ///   - opacity: 0.1~1.0
    ///   - isReveal: true=컬러 살리기(mask→0), false=흑백으로(mask→1)
    func paint(
        on maskTexture: MTLTexture,
        normalizedX: Float,
        normalizedY: Float,
        size: Float,
        softness: Float,
        opacity: Float,
        isReveal: Bool
    ) {
        guard
            let pipeline = brushPipeline,
            let cmdBuf = commandQueue.makeCommandBuffer(),
            let encoder = cmdBuf.makeComputeCommandEncoder()
        else { return }

        let pixelX = normalizedX * Float(maskTexture.width)
        let pixelY = normalizedY * Float(maskTexture.height)

        // 브러시 반경: 이미지 크기에 비례
        let radiusInPixels = (size / 150.0) * Float(min(maskTexture.width, maskTexture.height)) * 0.15

        var params = BrushParams(
            center: SIMD2<Float>(pixelX, pixelY),
            radius: max(radiusInPixels, 2.0),
            softness: softness,
            opacity: opacity,
            targetValue: isReveal ? 0.0 : 1.0
        )

        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(maskTexture, index: 0)
        encoder.setBytes(&params, length: MemoryLayout<BrushParams>.stride, index: 0)

        // 브러시 영역에만 스레드 디스패치 (최적화)
        let brushDiameter = Int(params.radius * 2) + 4
        let startX = max(0, Int(pixelX) - brushDiameter / 2)
        let startY = max(0, Int(pixelY) - brushDiameter / 2)
        let endX = min(maskTexture.width, startX + brushDiameter)
        let endY = min(maskTexture.height, startY + brushDiameter)

        let regionW = max(1, endX - startX)
        let regionH = max(1, endY - startY)

        let threads = MTLSize(width: 16, height: 16, depth: 1)
        let groups = MTLSize(
            width: (regionW + 15) / 16,
            height: (regionH + 15) / 16,
            depth: 1
        )
        encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: threads)
        encoder.endEncoding()

        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()
    }
}
