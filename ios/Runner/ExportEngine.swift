import UIKit
import Photos
import Metal
import CoreImage

/// 고해상도 내보내기 + Photos/공유 처리 엔진
class ExportEngine {

    // MARK: - Photos 저장

    /// JPEG 데이터를 카메라 롤에 저장한다
    /// - Returns: 저장 성공 여부
    static func saveToPhotos(jpegData: Data, completion: @escaping (Bool, String?) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                completion(false, "사진 접근 권한이 없습니다")
                return
            }
            guard let image = UIImage(data: jpegData) else {
                completion(false, "이미지 변환 실패")
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                completion(success, error?.localizedDescription)
            }
        }
    }

    // MARK: - 시스템 공유

    /// JPEG 데이터를 UIActivityViewController로 공유한다
    /// - Parameter sourceRect: 공유 버튼 위치 (iPad 팝오버용)
    static func shareImage(
        jpegData: Data,
        sourceRect: CGRect,
        completion: @escaping (Bool) -> Void
    ) {
        guard let image = UIImage(data: jpegData) else {
            completion(false)
            return
        }

        DispatchQueue.main.async {
            guard
                let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                let rootVC = windowScene.windows.first?.rootViewController
            else {
                completion(false)
                return
            }

            // 최상단 뷰컨트롤러 탐색
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }

            let activityVC = UIActivityViewController(
                activityItems: [image],
                applicationActivities: nil
            )

            // iPad: 팝오버 위치 설정
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = topVC.view
                popover.sourceRect = sourceRect
            }

            activityVC.completionWithItemsHandler = { _, completed, _, _ in
                completion(completed)
            }

            topVC.present(activityVC, animated: true)
        }
    }

    // MARK: - Loop 영상 공유

    /// MP4 파일을 시스템 공유 시트로 내보낸다
    static func shareVideo(
        url: URL,
        sourceRect: CGRect,
        completion: @escaping (Bool) -> Void
    ) {
        DispatchQueue.main.async {
            guard
                let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                let rootVC = windowScene.windows.first?.rootViewController
            else {
                completion(false)
                return
            }

            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }

            let activityVC = UIActivityViewController(
                activityItems: [url],
                applicationActivities: nil
            )

            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = topVC.view
                popover.sourceRect = sourceRect
            }

            activityVC.completionWithItemsHandler = { _, completed, _, _ in
                // 임시 파일 정리
                try? FileManager.default.removeItem(at: url)
                completion(completed)
            }

            topVC.present(activityVC, animated: true)
        }
    }
}
