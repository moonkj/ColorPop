import Flutter
import UIKit
import Metal
import AVFoundation

/// ColorPop Export Platform Channel
/// com.colorpop/export
class ExportChannel {
    static let channelName = "com.colorpop/export"

    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)

        channel.setMethodCallHandler { call, result in
            guard let session = ImageProcessingChannel.session else {
                result(FlutterError(code: "NO_SESSION", message: "편집 세션이 없습니다", details: nil))
                return
            }

            switch call.method {

            // ── 현재 렌더 프레임 고화질 JPEG 반환 ──────────────────
            case "getExportFrame":
                let quality = (call.arguments as? [String: Any])?["quality"] as? Double ?? 0.95
                DispatchQueue.global(qos: .userInitiated).async {
                    let data = session.exportRenderData(quality: CGFloat(quality))
                    DispatchQueue.main.async {
                        if let d = data {
                            result(FlutterStandardTypedData(bytes: d))
                        } else {
                            result(FlutterError(code: "RENDER_ERROR", message: "렌더링 실패", details: nil))
                        }
                    }
                }

            // ── Photos 저장 ────────────────────────────────────────
            case "saveToPhotos":
                let quality = (call.arguments as? [String: Any])?["quality"] as? Double ?? 0.95
                DispatchQueue.global(qos: .userInitiated).async {
                    guard let jpegData = session.exportRenderData(quality: CGFloat(quality)) else {
                        DispatchQueue.main.async {
                            result(FlutterError(code: "RENDER_ERROR", message: "렌더링 실패", details: nil))
                        }
                        return
                    }
                    ExportEngine.saveToPhotos(jpegData: jpegData) { success, errorMsg in
                        DispatchQueue.main.async {
                            if success {
                                result(true)
                            } else {
                                result(FlutterError(
                                    code: "SAVE_ERROR",
                                    message: errorMsg ?? "저장 실패",
                                    details: nil
                                ))
                            }
                        }
                    }
                }

            // ── 시스템 공유 시트 ───────────────────────────────────
            case "shareImage":
                let quality = (call.arguments as? [String: Any])?["quality"] as? Double ?? 0.92
                DispatchQueue.global(qos: .userInitiated).async {
                    guard let jpegData = session.exportRenderData(quality: CGFloat(quality)) else {
                        DispatchQueue.main.async {
                            result(FlutterError(code: "RENDER_ERROR", message: "렌더링 실패", details: nil))
                        }
                        return
                    }
                    ExportEngine.shareImage(
                        jpegData: jpegData,
                        sourceRect: CGRect(x: UIScreen.main.bounds.midX, y: 100, width: 1, height: 1)
                    ) { completed in
                        DispatchQueue.main.async { result(completed) }
                    }
                }

            // ── Loop 영상 생성 + 공유 ─────────────────────────────
            case "generateAndShareLoop":
                DispatchQueue.global(qos: .userInitiated).async {
                    guard let videoURL = session.generateLoopVideo() else {
                        DispatchQueue.main.async {
                            result(FlutterError(
                                code: "VIDEO_ERROR",
                                message: "Loop 영상 생성 실패",
                                details: nil
                            ))
                        }
                        return
                    }
                    ExportEngine.shareVideo(
                        url: videoURL,
                        sourceRect: CGRect(x: UIScreen.main.bounds.midX, y: 100, width: 1, height: 1)
                    ) { completed in
                        DispatchQueue.main.async { result(completed) }
                    }
                }

            // ── Loop 영상 Photos 저장 ─────────────────────────────
            case "saveLoopToPhotos":
                DispatchQueue.global(qos: .userInitiated).async {
                    guard let videoURL = session.generateLoopVideo() else {
                        DispatchQueue.main.async {
                            result(FlutterError(
                                code: "VIDEO_ERROR",
                                message: "Loop 영상 생성 실패",
                                details: nil
                            ))
                        }
                        return
                    }
                    UISaveVideoAtPathToSavedPhotosAlbum(videoURL.path, nil, nil, nil)
                    // 짧은 지연 후 임시 파일 정리 (저장이 완료될 시간 확보)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        try? FileManager.default.removeItem(at: videoURL)
                    }
                    DispatchQueue.main.async { result(true) }
                }

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}
