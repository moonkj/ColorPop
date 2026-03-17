import Metal
import CoreImage
import UIKit

/// Metal Compute Shader로 Color Pop 합성 렌더링
/// colorTexture + grayTexture + maskTexture → (이펙트 적용) → JPEG Data
class ColorPopBlendRenderer {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let ciContext: CIContext
    private var blendPipeline: MTLComputePipelineState?
    private var outputTexture: MTLTexture?
    private let effectsEngine: EffectsEngine

    init(device: MTLDevice, commandQueue: MTLCommandQueue, effectsEngine: EffectsEngine) {
        self.device = device
        self.commandQueue = commandQueue
        self.effectsEngine = effectsEngine
        self.ciContext = CIContext(mtlDevice: device, options: [.useSoftwareRenderer: false])
        setupPipeline()
    }

    private func setupPipeline() {
        guard
            let library = device.makeDefaultLibrary(),
            let fn = library.makeFunction(name: "colorPopBlend")
        else {
            print("[Renderer] colorPopBlend 함수 로드 실패")
            return
        }
        blendPipeline = try? device.makeComputePipelineState(function: fn)
    }

    private func ensureOutputTexture(width: Int, height: Int) -> MTLTexture? {
        if let tex = outputTexture, tex.width == width, tex.height == height {
            return tex
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .shared
        outputTexture = device.makeTexture(descriptor: descriptor)
        return outputTexture
    }

    /// 합성 + 이펙트 렌더링 → JPEG Data 반환
    func render(
        colorTexture: MTLTexture,
        grayTexture: MTLTexture,
        maskTexture: MTLTexture,
        effectType: EffectsEngine.EffectType = .none,
        effectIntensity: Float = 0.5,
        isInverse: Bool = false,
        jpegQuality: CGFloat = 0.88
    ) -> Data? {
        guard
            let pipeline = blendPipeline,
            let blendedTex = ensureOutputTexture(
                width: colorTexture.width, height: colorTexture.height
            ),
            let cmdBuf = commandQueue.makeCommandBuffer(),
            let encoder = cmdBuf.makeComputeCommandEncoder()
        else { return nil }

        // Step 1: colorPopBlend (isInverse 지원)
        var blendParams = BlendParams(isInverse: isInverse ? 1.0 : 0.0)
        guard let blendBuf = device.makeBuffer(
            bytes: &blendParams,
            length: MemoryLayout<BlendParams>.size,
            options: .storageModeShared
        ) else { return nil }

        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(colorTexture, index: 0)
        encoder.setTexture(grayTexture,  index: 1)
        encoder.setTexture(maskTexture,  index: 2)
        encoder.setTexture(blendedTex,   index: 3)
        encoder.setBuffer(blendBuf, offset: 0, index: 0)

        let threads = MTLSize(width: 16, height: 16, depth: 1)
        let groups  = MTLSize(
            width:  (blendedTex.width  + 15) / 16,
            height: (blendedTex.height + 15) / 16,
            depth:  1
        )
        encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: threads)
        encoder.endEncoding()
        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()

        // Step 2: 이펙트 패스 (none이면 blendedTex 그대로 사용)
        let finalTex = effectsEngine.apply(
            blended: blendedTex,
            mask: maskTexture,
            effectType: effectType,
            intensity: effectIntensity
        )

        return textureToJPEG(finalTex, quality: jpegQuality)
    }

    private func textureToJPEG(_ texture: MTLTexture, quality: CGFloat) -> Data? {
        let width = texture.width
        let height = texture.height
        let bytesPerRow = width * 4
        var rawBytes = [UInt8](repeating: 0, count: height * bytesPerRow)
        texture.getBytes(
            &rawBytes,
            bytesPerRow: bytesPerRow,
            from: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0
        )
        guard
            let provider = CGDataProvider(data: Data(rawBytes) as CFData),
            let cgImage = CGImage(
                width: width, height: height,
                bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil, shouldInterpolate: true,
                intent: .defaultIntent
            )
        else { return nil }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: quality)
    }
}

// Metal struct과 메모리 레이아웃 일치
private struct BlendParams {
    var isInverse: Float
}
