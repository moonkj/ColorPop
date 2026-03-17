import Metal
import CoreImage
import UIKit

/// Metal 텍스처 기반 마스크 관리 엔진
/// 편집 세션 동안 MTLTexture 상태를 유지한다
class MaskEngine {
    let device: MTLDevice
    private(set) var maskTexture: MTLTexture?    // R32Float (0=컬러, 1=흑백)
    private(set) var imageSize: CGSize = .zero

    // Metal 커널 파이프라인
    private var fillPipeline: MTLComputePipelineState?
    private var commandQueue: MTLCommandQueue?

    init(device: MTLDevice) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()
        setupPipelines()
    }

    private func setupPipelines() {
        guard let library = device.makeDefaultLibrary() else {
            print("[MaskEngine] Metal library 로드 실패")
            return
        }
        if let fn = library.makeFunction(name: "fillMask") {
            fillPipeline = try? device.makeComputePipelineState(function: fn)
        }
    }

    // 이미지 크기에 맞는 마스크 텍스처 초기화 (초기값: 1.0 = 전체 흑백)
    func initialize(imageSize: CGSize) {
        self.imageSize = imageSize
        let width = Int(imageSize.width)
        let height = Int(imageSize.height)

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r32Float,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .shared

        maskTexture = device.makeTexture(descriptor: descriptor)
        fillMask(value: 1.0)   // 전체 흑백으로 초기화
    }

    // 마스크 전체를 단일 값으로 채움
    func fillMask(value: Float) {
        guard
            let mask = maskTexture,
            let pipeline = fillPipeline,
            let queue = commandQueue,
            let cmdBuf = queue.makeCommandBuffer(),
            let encoder = cmdBuf.makeComputeCommandEncoder()
        else { return }

        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(mask, index: 0)
        var v = value
        encoder.setBytes(&v, length: MemoryLayout<Float>.size, index: 0)

        let threads = MTLSize(width: 16, height: 16, depth: 1)
        let groups = MTLSize(
            width: (mask.width + 15) / 16,
            height: (mask.height + 15) / 16,
            depth: 1
        )
        encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: threads)
        encoder.endEncoding()
        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()
    }

    // 현재 마스크 상태를 PNG Data로 스냅샷 (Undo용)
    func takeSnapshot() -> Data? {
        guard let mask = maskTexture else { return nil }
        let width = mask.width
        let height = mask.height

        // R32Float → UInt8 변환 후 PNG 압축
        var floatPixels = [Float](repeating: 0, count: width * height)
        mask.getBytes(
            &floatPixels,
            bytesPerRow: width * MemoryLayout<Float>.size,
            from: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0
        )

        // Float → UInt8 (0~255)
        let uint8Pixels = floatPixels.map { UInt8(($0 * 255).clamped(to: 0...255)) }
        let data = Data(uint8Pixels)
        return data
    }

    // Float32 배열로 마스크 전체를 교체한다 (AI 마스크 적용)
    func loadFromFloatArray(_ floatData: [Float]) {
        guard let mask = maskTexture,
              floatData.count == mask.width * mask.height
        else { return }
        var data = floatData
        mask.replace(
            region: MTLRegionMake2D(0, 0, mask.width, mask.height),
            mipmapLevel: 0,
            withBytes: &data,
            bytesPerRow: mask.width * MemoryLayout<Float>.size
        )
    }

    // 스냅샷 데이터로 마스크 복원 (Undo/Redo)
    func restoreSnapshot(_ snapshotData: Data) {
        guard let mask = maskTexture else { return }
        let width = mask.width
        let height = mask.height
        guard snapshotData.count == width * height else { return }

        // UInt8 → Float 변환
        var floatPixels = snapshotData.map { Float($0) / 255.0 }
        mask.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: &floatPixels,
            bytesPerRow: width * MemoryLayout<Float>.size
        )
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
