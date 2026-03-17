import Flutter
import Metal
import AVFoundation
import UIKit

/// 카메라 Platform Channel
/// Flutter ↔ Swift 카메라 통신 (com.colorpop/camera)
/// FlutterTexture를 통해 GPU 버퍼를 Flutter Texture 위젯에 직접 노출
class CameraChannel: NSObject {
    static let channelName = "com.colorpop/camera"

    private static let device: MTLDevice = MTLCreateSystemDefaultDevice()!
    private static var engine: CameraEngine?
    private static var flutterTexture: ColorPopCameraTexture?
    private static var textureId: Int64 = -1
    private static weak var textureRegistry: FlutterTextureRegistry?

    // MARK: - 채널 등록

    static func register(
        with messenger: FlutterBinaryMessenger,
        textureRegistry: FlutterTextureRegistry
    ) {
        self.textureRegistry = textureRegistry
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)

        channel.setMethodCallHandler { call, result in
            switch call.method {

            // ── 카메라 초기화 + FlutterTexture 등록 ─────────────────
            // 반환: { "textureId": Int64, "hasLiDAR": Bool }
            case "initCamera":
                let args = call.arguments as? [String: Any]
                let posStr = args?["position"] as? String ?? "back"
                let position: AVCaptureDevice.Position = posStr == "front" ? .front : .back

                let commandQueue = device.makeCommandQueue()!
                let cam = CameraEngine(device: device, commandQueue: commandQueue)
                engine = cam

                let tex = ColorPopCameraTexture()
                flutterTexture = tex
                let tid = textureRegistry.register(tex)
                textureId = tid

                // 프레임 준비 시 Flutter Texture 갱신 알림
                cam.onFrameReady = { pixelBuffer in
                    tex.updateBuffer(pixelBuffer)
                    DispatchQueue.main.async {
                        textureRegistry.textureFrameAvailable(tid)
                    }
                }

                cam.startSession(position: position)

                result([
                    "textureId": tid,
                    "hasLiDAR": CameraEngine.hasLiDAR,
                ])

            // ── 카메라 세션 종료 ─────────────────────────────────────
            case "disposeCamera":
                engine?.stopSession()
                if textureId >= 0 {
                    textureRegistry.unregisterTexture(textureId)
                    textureId = -1
                }
                engine = nil
                flutterTexture = nil
                result(nil)

            // ── 전면/후면 전환 ───────────────────────────────────────
            case "switchCamera":
                engine?.switchCamera()
                result(nil)

            // ── 반전 모드 설정 ───────────────────────────────────────
            case "setInverseMode":
                let args = call.arguments as? [String: Any]
                let inv = args?["isInverse"] as? Bool ?? false
                engine?.isInverseMode = inv
                result(nil)

            // ── 사진 촬영 ────────────────────────────────────────────
            // 반환: Uint8List (JPEG Data)
            case "capturePhoto":
                guard let cam = engine else {
                    result(FlutterError(code: "NO_SESSION", message: "카메라 세션 없음", details: nil))
                    return
                }
                cam.onPhotoCaptured = { data in
                    DispatchQueue.main.async {
                        result(FlutterStandardTypedData(bytes: data))
                    }
                }
                cam.onError = { msg in
                    DispatchQueue.main.async {
                        result(FlutterError(code: "CAPTURE_ERROR", message: msg, details: nil))
                    }
                }
                cam.capturePhoto()

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}

// MARK: - ColorPopCameraTexture

/// FlutterTexture 구현체
/// 카메라 렌더링 결과인 CVPixelBuffer를 Flutter에 노출한다
class ColorPopCameraTexture: NSObject, FlutterTexture {
    private let lock = NSLock()
    private var buffer: CVPixelBuffer?

    func updateBuffer(_ newBuffer: CVPixelBuffer) {
        lock.lock()
        buffer = newBuffer
        lock.unlock()
    }

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        lock.lock()
        defer { lock.unlock() }
        guard let buf = buffer else { return nil }
        return Unmanaged.passRetained(buf)
    }
}
