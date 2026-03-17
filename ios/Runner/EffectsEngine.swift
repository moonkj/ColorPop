import Metal

/// Phase 5 이펙트 엔진 — Metal Compute 커널 기반 비파괴 이펙트 처리
class EffectsEngine {

    enum EffectType: String {
        case none, neonGlow, chromatic, filmGrain, bgBlur, filmNoir

        static func from(_ string: String) -> EffectType {
            return EffectType(rawValue: string) ?? .none
        }
    }

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelines: [String: MTLComputePipelineState] = [:]
    private var outputTexture: MTLTexture?
    private var frameCounter: Float = 0.0

    init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        self.device = device
        self.commandQueue = commandQueue
        setupPipelines()
    }

    private func setupPipelines() {
        guard let library = device.makeDefaultLibrary() else {
            print("[EffectsEngine] Metal 라이브러리 로드 실패")
            return
        }
        let kernelNames = ["neonGlowEffect", "chromaticEffect", "filmGrainEffect",
                           "bgBlurEffect", "filmNoirEffect"]
        for name in kernelNames {
            guard
                let fn = library.makeFunction(name: name),
                let pipeline = try? device.makeComputePipelineState(function: fn)
            else {
                print("[EffectsEngine] \(name) 파이프라인 로드 실패")
                continue
            }
            pipelines[name] = pipeline
        }
    }

    // 재사용 출력 텍스처 (크기 변경 시만 재생성)
    private func ensureOutputTexture(width: Int, height: Int) -> MTLTexture? {
        if let tex = outputTexture, tex.width == width, tex.height == height {
            return tex
        }
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false
        )
        desc.usage = [.shaderRead, .shaderWrite]
        desc.storageMode = .shared
        outputTexture = device.makeTexture(descriptor: desc)
        return outputTexture
    }

    /// 블렌드된 텍스처에 이펙트를 적용한다
    /// - Returns: 이펙트 적용된 MTLTexture. none이거나 실패 시 blended 반환
    func apply(
        blended: MTLTexture,
        mask: MTLTexture,
        effectType: EffectType,
        intensity: Float
    ) -> MTLTexture {
        guard effectType != .none else { return blended }

        let kernelName: String
        switch effectType {
        case .neonGlow:  kernelName = "neonGlowEffect"
        case .chromatic: kernelName = "chromaticEffect"
        case .filmGrain: kernelName = "filmGrainEffect"
        case .bgBlur:    kernelName = "bgBlurEffect"
        case .filmNoir:  kernelName = "filmNoirEffect"
        case .none:      return blended
        }

        guard
            let pipeline = pipelines[kernelName],
            let outTex = ensureOutputTexture(width: blended.width, height: blended.height),
            let cmdBuf = commandQueue.makeCommandBuffer(),
            let encoder = cmdBuf.makeComputeCommandEncoder()
        else { return blended }

        frameCounter += 1.0
        var params = EffectParams(intensity: intensity, frameCount: frameCounter)
        guard let paramBuf = device.makeBuffer(
            bytes: &params,
            length: MemoryLayout<EffectParams>.size,
            options: .storageModeShared
        ) else { return blended }

        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(blended, index: 0)
        encoder.setTexture(mask,    index: 1)
        encoder.setTexture(outTex,  index: 2)
        encoder.setBuffer(paramBuf, offset: 0, index: 0)

        let threads = MTLSize(width: 16, height: 16, depth: 1)
        let groups  = MTLSize(
            width:  (outTex.width  + 15) / 16,
            height: (outTex.height + 15) / 16,
            depth:  1
        )
        encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: threads)
        encoder.endEncoding()
        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()

        return outTex
    }
}

// Metal struct (반드시 Metal 쪽 EffectParams와 메모리 레이아웃 일치)
private struct EffectParams {
    var intensity:  Float
    var frameCount: Float
}
