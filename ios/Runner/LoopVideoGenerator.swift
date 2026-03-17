import UIKit
import AVFoundation
import Metal
import CoreGraphics

/// B&W → Color → B&W 루프 MP4를 생성한다
/// - 30fps × 90프레임 = 3초 루프
/// - Metal로 각 프레임의 마스크 강도를 보간하여 렌더링
class LoopVideoGenerator {

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue

    // 루프 파라미터
    private let fps: Int = 30
    private let durationSeconds: Double = 3.0

    // 마스크 강도 곡선: 0→1→0 사인 보간
    private func maskIntensity(at frame: Int, totalFrames: Int) -> Float {
        let t = Float(frame) / Float(totalFrames - 1)  // 0.0 ~ 1.0
        // 0→1→0 반사인 곡선
        return sin(t * Float.pi)
    }

    init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        self.device = device
        self.commandQueue = commandQueue
    }

    /// 루프 영상 생성
    /// - Parameters:
    ///   - colorImage: 원본 컬러 이미지
    ///   - grayImage: 흑백 이미지
    ///   - maskData: Float32 마스크 배열 (0=컬러, 1=흑백)
    ///   - maskWidth: 마스크 너비
    ///   - maskHeight: 마스크 높이
    /// - Returns: 임시 MP4 파일 URL (nil = 실패)
    func generate(
        colorImage: UIImage,
        grayImage: UIImage,
        maskData: [Float],
        maskWidth: Int,
        maskHeight: Int
    ) -> URL? {
        guard
            let cgColor = colorImage.cgImage,
            let cgGray  = grayImage.cgImage
        else { return nil }

        let width  = cgColor.width
        let height = cgColor.height
        let totalFrames = Int(Double(fps) * durationSeconds)

        // 임시 파일 경로
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("colorpop_loop_\(Int(Date().timeIntervalSince1970)).mp4")

        // AVAssetWriter 설정
        guard let writer = try? AVAssetWriter(outputURL: tempURL, fileType: .mp4) else {
            return nil
        }

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: width * height * 2,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ],
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = false

        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: attributes
        )

        guard writer.canAdd(input) else { return nil }
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        // 컬러 / 흑백 픽셀 데이터 준비 (BGRA)
        let colorPixels = extractBGRA(from: cgColor, width: width, height: height)
        let grayPixels  = extractBGRA(from: cgGray,  width: width, height: height)

        guard let colorPix = colorPixels, let grayPix = grayPixels else {
            writer.cancelWriting()
            return nil
        }

        // 마스크를 영상 해상도로 업스케일
        let scaledMask = scaleMask(
            maskData, maskWidth: maskWidth, maskHeight: maskHeight,
            targetWidth: width, targetHeight: height
        )

        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))

        for frame in 0..<totalFrames {
            // 큐가 준비될 때까지 대기
            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.01)
            }

            let intensity = maskIntensity(at: frame, totalFrames: totalFrames)
            guard let pixelBuffer = makeFrame(
                colorPixels: colorPix,
                grayPixels: grayPix,
                mask: scaledMask,
                intensity: intensity,
                width: width, height: height,
                pool: adaptor.pixelBufferPool
            ) else { continue }

            let presentTime = CMTimeMultiply(frameDuration, multiplier: Int32(frame))
            adaptor.append(pixelBuffer, withPresentationTime: presentTime)
        }

        input.markAsFinished()

        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting { semaphore.signal() }
        semaphore.wait()

        return writer.status == .completed ? tempURL : nil
    }

    // MARK: - 프레임 합성

    /// 마스크 강도에 따라 컬러/흑백 블렌딩 픽셀 버퍼 생성
    /// intensity: 0.0 = 완전 컬러, 1.0 = 완전 흑백
    private func makeFrame(
        colorPixels: [UInt8],
        grayPixels:  [UInt8],
        mask: [Float],
        intensity: Float,
        width: Int, height: Int,
        pool: CVPixelBufferPool?
    ) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        if let pool = pool {
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
        } else {
            CVPixelBufferCreate(
                nil, width, height,
                kCVPixelFormatType_32BGRA, nil,
                &pixelBuffer
            )
        }
        guard let pb = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(pb, [])
        guard let base = CVPixelBufferGetBaseAddress(pb) else {
            CVPixelBufferUnlockBaseAddress(pb, [])
            return nil
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pb)
        let pixelCount  = width * height

        for i in 0..<pixelCount {
            // 마스크 값 × 강도: 높을수록 흑백
            let maskVal = min(mask[i] * intensity, 1.0)
            let invMask = 1.0 - maskVal

            let base4 = i * 4
            // BGRA 순서
            let b = UInt8(Float(colorPixels[base4 + 0]) * invMask + Float(grayPixels[base4 + 0]) * maskVal)
            let g = UInt8(Float(colorPixels[base4 + 1]) * invMask + Float(grayPixels[base4 + 1]) * maskVal)
            let r = UInt8(Float(colorPixels[base4 + 2]) * invMask + Float(grayPixels[base4 + 2]) * maskVal)

            let row    = i / width
            let col    = i % width
            let offset = row * bytesPerRow + col * 4

            base.storeBytes(of: b, toByteOffset: offset,     as: UInt8.self)
            base.storeBytes(of: g, toByteOffset: offset + 1, as: UInt8.self)
            base.storeBytes(of: r, toByteOffset: offset + 2, as: UInt8.self)
            base.storeBytes(of: 255, toByteOffset: offset + 3, as: UInt8.self)
        }

        CVPixelBufferUnlockBaseAddress(pb, [])
        return pb
    }

    // MARK: - 유틸

    private func extractBGRA(from cgImage: CGImage, width: Int, height: Int) -> [UInt8]? {
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let ctx = CGContext(
            data: &pixels,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue |
                        CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return nil }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }

    /// 마스크를 최근방 보간으로 목표 해상도로 업스케일
    private func scaleMask(
        _ mask: [Float],
        maskWidth: Int, maskHeight: Int,
        targetWidth: Int, targetHeight: Int
    ) -> [Float] {
        guard maskWidth != targetWidth || maskHeight != targetHeight else { return mask }
        var result = [Float](repeating: 0, count: targetWidth * targetHeight)
        let scaleX = Float(maskWidth)  / Float(targetWidth)
        let scaleY = Float(maskHeight) / Float(targetHeight)
        for ty in 0..<targetHeight {
            for tx in 0..<targetWidth {
                let mx = min(Int(Float(tx) * scaleX), maskWidth  - 1)
                let my = min(Int(Float(ty) * scaleY), maskHeight - 1)
                result[ty * targetWidth + tx] = mask[my * maskWidth + mx]
            }
        }
        return result
    }
}
