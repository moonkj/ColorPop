import AVFoundation
import CoreImage
import Metal
import UIKit
import Vision

/// AVFoundation 기반 실시간 카메라 엔진
/// 30fps 캡처 → 15fps AI 세그멘테이션 → Temporal Smoothing → Color Splash 렌더링
class CameraEngine: NSObject {

    // MARK: - Metal 리소스

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue

    // Metal 파이프라인 (ColorPopBlend.metal 커널)
    private var grayscalePipeline: MTLComputePipelineState?
    private var temporalSmoothPipeline: MTLComputePipelineState?
    private var realtimeSplashPipeline: MTLComputePipelineState?

    // 마스크 텍스처 (R32Float)
    private var rawMaskTexture: MTLTexture?       // 새 AI 마스크 (로딩 임시)
    private var smoothedMaskTexture: MTLTexture?  // EMA 결과 (렌더링용)
    private var prevSmoothedTexture: MTLTexture?  // 이전 EMA 결과

    // 컬러/흑백 중간 텍스처 (BGRA8Unorm)
    private var grayTexture: MTLTexture?

    // 출력 CVPixelBuffer + Metal 텍스처 (FlutterTexture 백킹)
    private(set) var outputPixelBuffer: CVPixelBuffer?
    private var outputMTLTexture: MTLTexture?
    private var outputCVMetalTexture: CVMetalTexture?

    // CVMetalTextureCache (픽셀 버퍼 ↔ Metal 텍스처 변환)
    private var textureCache: CVMetalTextureCache?

    // MARK: - AI 처리

    private let personSegEngine = PersonSegmentationEngine()
    private lazy var ciContext = CIContext(
        mtlDevice: device, options: [.useSoftwareRenderer: false]
    )

    // 프레임 카운터 (15fps AI: 2프레임마다 1회)
    private var frameCount = 0

    // AI 결과를 렌더링 스레드에 안전하게 전달
    private let maskLock = NSLock()
    private var pendingMaskFloats: [Float]?

    // MARK: - AVFoundation

    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var currentPosition: AVCaptureDevice.Position = .back

    // MARK: - 상태

    var isInverseMode: Bool = false

    // LiDAR 지원 여부 (A-4 Depth-Aware Splash)
    static var hasLiDAR: Bool = {
        if #available(iOS 15.4, *) {
            return AVCaptureDevice.default(
                .builtInLiDARDepthCamera, for: .depthData, position: .back
            ) != nil
        }
        return false
    }()

    // MARK: - 콜백

    var onFrameReady: ((CVPixelBuffer) -> Void)?
    var onPhotoCaptured: ((Data) -> Void)?
    var onError: ((String) -> Void)?

    // MARK: - 초기화

    init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        self.device = device
        self.commandQueue = commandQueue
        super.init()
        setupPipelines()
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
    }

    private func setupPipelines() {
        guard let library = device.makeDefaultLibrary() else {
            print("[CameraEngine] Metal 라이브러리 로드 실패")
            return
        }
        let make = { (name: String) -> MTLComputePipelineState? in
            guard let fn = library.makeFunction(name: name) else {
                print("[CameraEngine] 커널 로드 실패: \(name)")
                return nil
            }
            return try? self.device.makeComputePipelineState(function: fn)
        }
        grayscalePipeline     = make("makeGrayscale")
        temporalSmoothPipeline = make("temporalSmooth")
        realtimeSplashPipeline = make("realtimeColorSplash")
    }

    // MARK: - 세션 시작/종료

    func startSession(position: AVCaptureDevice.Position = .back) {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .hd1280x720
        captureSession.inputs.forEach  { captureSession.removeInput($0) }
        captureSession.outputs.forEach { captureSession.removeOutput($0) }

        guard
            let camera = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: position
            ),
            let input = try? AVCaptureDeviceInput(device: camera)
        else {
            captureSession.commitConfiguration()
            onError?("카메라를 초기화할 수 없습니다")
            return
        }

        captureSession.addInput(input)
        currentPosition = position

        // 30fps 고정 (AI + 렌더링 부하 균형)
        try? camera.lockForConfiguration()
        camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
        camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
        camera.unlockForConfiguration()

        // 비디오 출력 설정
        videoOutput.setSampleBufferDelegate(
            self,
            queue: DispatchQueue(label: "com.colorpop.camera.capture", qos: .userInteractive)
        )
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        captureSession.addOutput(videoOutput)

        // 방향 + 미러링 설정
        if let conn = videoOutput.connection(with: .video) {
            conn.videoOrientation = .portrait
            conn.isVideoMirrored = (position == .front)
        }

        captureSession.addOutput(photoOutput)
        captureSession.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }

    func stopSession() {
        captureSession.stopRunning()
        resetTextures()
    }

    func switchCamera() {
        let next: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
        startSession(position: next)
    }

    private func resetTextures() {
        outputPixelBuffer   = nil
        outputMTLTexture    = nil
        outputCVMetalTexture = nil
        rawMaskTexture       = nil
        smoothedMaskTexture  = nil
        prevSmoothedTexture  = nil
        grayTexture          = nil
    }

    // MARK: - 사진 촬영

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - Metal 리소스 초기화 (첫 프레임 또는 해상도 변경 시)

    private func ensureResources(width: Int, height: Int) {
        guard
            rawMaskTexture == nil ||
            rawMaskTexture?.width != width ||
            rawMaskTexture?.height != height
        else { return }

        // R32Float 마스크 텍스처 3종
        let maskDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r32Float, width: width, height: height, mipmapped: false
        )
        maskDesc.usage = [.shaderRead, .shaderWrite]
        maskDesc.storageMode = .shared

        rawMaskTexture      = device.makeTexture(descriptor: maskDesc)
        smoothedMaskTexture = device.makeTexture(descriptor: maskDesc)
        prevSmoothedTexture = device.makeTexture(descriptor: maskDesc)

        // 초기 마스크: 전체 1.0 (흑백 상태)
        let ones = [Float](repeating: 1.0, count: width * height)
        ones.withUnsafeBytes { ptr in
            [rawMaskTexture, smoothedMaskTexture, prevSmoothedTexture].forEach { tex in
                tex?.replace(
                    region: MTLRegionMake2D(0, 0, width, height),
                    mipmapLevel: 0,
                    withBytes: ptr.baseAddress!,
                    bytesPerRow: width * MemoryLayout<Float>.size
                )
            }
        }

        // 흑백 변환 중간 텍스처 (BGRA)
        let colorDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false
        )
        colorDesc.usage = [.shaderRead, .shaderWrite]
        colorDesc.storageMode = .shared
        grayTexture = device.makeTexture(descriptor: colorDesc)

        // 출력 CVPixelBuffer (FlutterTexture 백킹)
        var buf: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
        ]
        CVPixelBufferCreate(
            kCFAllocatorDefault, width, height,
            kCVPixelFormatType_32BGRA, attrs as CFDictionary, &buf
        )
        outputPixelBuffer = buf

        guard let buf = buf, let cache = textureCache else { return }
        var cvTex: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault, cache, buf, nil,
            .bgra8Unorm, width, height, 0, &cvTex
        )
        outputCVMetalTexture = cvTex
        if let cvTex = cvTex {
            outputMTLTexture = CVMetalTextureGetTexture(cvTex)
        }
    }

    // MARK: - 프레임 처리 (카메라 캡처 큐에서 실행)

    private func processFrame(pixelBuffer: CVPixelBuffer) {
        let width  = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        ensureResources(width: width, height: height)

        // 카메라 CVPixelBuffer → Metal 텍스처
        guard let cache = textureCache else { return }
        var cvTexRef: CVMetalTexture?
        guard
            CVMetalTextureCacheCreateTextureFromImage(
                kCFAllocatorDefault, cache, pixelBuffer, nil,
                .bgra8Unorm, width, height, 0, &cvTexRef
            ) == kCVReturnSuccess,
            let cvTexRef = cvTexRef,
            let colorTexture = CVMetalTextureGetTexture(cvTexRef)
        else { return }

        frameCount += 1

        // 15fps AI 세그멘테이션 (2프레임마다 1회)
        if frameCount % 2 == 0 {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let uiImage = UIImage(ciImage: ciImage)
            Task.detached(priority: .utility) { [weak self] in
                guard let self = self else { return }
                if let maskCI = await self.personSegEngine.segmentPerson(from: uiImage) {
                    self.convertAndStoreMask(maskCI, width: width, height: height)
                }
            }
        }

        // 대기 중인 AI 마스크 적용 + Temporal Smoothing
        applyPendingMaskIfNeeded(width: width, height: height)

        // GPU 파이프라인: Grayscale → Blend → Output
        renderFrame(colorTexture: colorTexture, width: width, height: height)
    }

    // MARK: - AI 마스크 변환 + 저장 (백그라운드 Task에서 실행)

    private func convertAndStoreMask(_ maskCI: CIImage, width: Int, height: Int) {
        let scaleX = CGFloat(width)  / maskCI.extent.width
        let scaleY = CGFloat(height) / maskCI.extent.height
        let scaled = maskCI.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        var bitmap = [UInt8](repeating: 0, count: width * height * 4)
        ciContext.render(
            scaled,
            toBitmap: &bitmap,
            rowBytes: width * 4,
            bounds: CGRect(x: 0, y: 0, width: width, height: height),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        // PersonSegmentationEngine이 이미 반전 처리 (0=인물/컬러, 1=배경/흑백)
        let floats = (0..<(width * height)).map { Float(bitmap[$0 * 4]) / 255.0 }

        maskLock.lock()
        pendingMaskFloats = floats
        maskLock.unlock()
    }

    // MARK: - Temporal Smoothing 적용

    private func applyPendingMaskIfNeeded(width: Int, height: Int) {
        maskLock.lock()
        let floats = pendingMaskFloats
        pendingMaskFloats = nil
        maskLock.unlock()

        guard
            let floats = floats,
            let rawTex      = rawMaskTexture,
            let smoothedTex = smoothedMaskTexture,
            let prevTex     = prevSmoothedTexture
        else { return }

        // 새 AI 결과를 rawMaskTexture에 로드
        floats.withUnsafeBytes { ptr in
            rawTex.replace(
                region: MTLRegionMake2D(0, 0, width, height),
                mipmapLevel: 0,
                withBytes: ptr.baseAddress!,
                bytesPerRow: width * MemoryLayout<Float>.size
            )
        }

        // Temporal Smoothing: temporalSmooth(raw, prev) → smoothed
        guard
            let pipeline = temporalSmoothPipeline,
            let cmdBuf = commandQueue.makeCommandBuffer(),
            let encoder = cmdBuf.makeComputeCommandEncoder()
        else { return }

        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(rawTex,      index: 0)
        encoder.setTexture(prevTex,     index: 1)
        encoder.setTexture(smoothedTex, index: 2)
        var alpha: Float = 0.3
        encoder.setBytes(&alpha, length: MemoryLayout<Float>.size, index: 0)
        dispatchThreadgroups(encoder: encoder, width: width, height: height)
        encoder.endEncoding()
        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()

        // prev ← smoothed (다음 프레임 EMA 입력으로 복사)
        guard
            let blitBuf  = commandQueue.makeCommandBuffer(),
            let blitEnc = blitBuf.makeBlitCommandEncoder()
        else { return }
        blitEnc.copy(from: smoothedTex, to: prevTex)
        blitEnc.endEncoding()
        blitBuf.commit()
        blitBuf.waitUntilCompleted()
    }

    // MARK: - GPU 렌더링: Grayscale + Color Splash

    private func renderFrame(colorTexture: MTLTexture, width: Int, height: Int) {
        guard
            let gray    = grayTexture,
            let mask    = smoothedMaskTexture,
            let output  = outputMTLTexture,
            let cmdBuf  = commandQueue.makeCommandBuffer()
        else { return }

        // Step 1: makeGrayscale (colorTexture → grayTexture)
        if let pipeline = grayscalePipeline,
           let encoder = cmdBuf.makeComputeCommandEncoder() {
            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(colorTexture, index: 0)
            encoder.setTexture(gray,         index: 1)
            dispatchThreadgroups(encoder: encoder, width: width, height: height)
            encoder.endEncoding()
        }

        // Step 2: realtimeColorSplash (color + gray + mask → output)
        if let pipeline = realtimeSplashPipeline,
           let encoder = cmdBuf.makeComputeCommandEncoder() {
            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(colorTexture, index: 0)
            encoder.setTexture(gray,         index: 1)
            encoder.setTexture(mask,         index: 2)
            encoder.setTexture(output,       index: 3)
            var inv: Float = isInverseMode ? 1.0 : 0.0
            encoder.setBytes(&inv, length: MemoryLayout<Float>.size, index: 0)
            dispatchThreadgroups(encoder: encoder, width: width, height: height)
            encoder.endEncoding()
        }

        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()

        if let outBuf = outputPixelBuffer {
            onFrameReady?(outBuf)
        }
    }

    // MARK: - 유틸

    private func dispatchThreadgroups(encoder: MTLComputeCommandEncoder, width: Int, height: Int) {
        let tg  = MTLSize(width: 16, height: 16, depth: 1)
        let tgs = MTLSize(width: (width + 15) / 16, height: (height + 15) / 16, depth: 1)
        encoder.dispatchThreadgroups(tgs, threadsPerThreadgroup: tg)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraEngine: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        processFrame(pixelBuffer: pixelBuffer)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraEngine: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil, let data = photo.fileDataRepresentation() else { return }
        onPhotoCaptured?(data)
    }
}
