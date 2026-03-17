import Vision
import CoreImage
import Metal
import UIKit

/// 인물 세그멘테이션 엔진
/// VNGeneratePersonSegmentationRequest + Guided Filter(Gaussian 근사) 엣지 보정
class PersonSegmentationEngine {

    // MARK: - 인물 세그멘테이션

    /// 인물 세그멘테이션 마스크를 생성한다
    /// - Parameter image: 원본 UIImage
    /// - Returns: CIImage 마스크 (0=인물/컬러, 1=배경/흑백), 실패 시 nil
    func segmentPerson(from image: UIImage) async -> CIImage? {
        guard let cgImage = image.cgImage else { return nil }

        return await withCheckedContinuation { continuation in
            let request = VNGeneratePersonSegmentationRequest()
            request.qualityLevel = .accurate
            request.outputPixelFormat = kCVPixelFormatType_OneComponent8

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
                return
            }

            guard let observation = request.results?.first else {
                continuation.resume(returning: nil)
                return
            }

            var maskImage = CIImage(cvPixelBuffer: observation.pixelBuffer)

            // 원본 이미지 크기에 맞게 스케일 조정
            let imageW = CGFloat(cgImage.width)
            let imageH = CGFloat(cgImage.height)
            let scaleX = imageW / maskImage.extent.width
            let scaleY = imageH / maskImage.extent.height
            maskImage = maskImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

            // Guided Filter 근사: 소프트한 경계를 위한 Gaussian Blur
            let refined = PersonSegmentationEngine.refineEdges(mask: maskImage)

            // 마스크 반전: VN(1=인물) → ColorPop(0=인물/컬러, 1=배경/흑백)
            let inverted = PersonSegmentationEngine.invertMask(refined) ?? refined
            continuation.resume(returning: inverted)
        }
    }

    // MARK: - 내부 유틸

    /// Guided Filter 근사: 작은 Gaussian Blur로 경계 안티앨리어싱
    private static func refineEdges(mask: CIImage) -> CIImage {
        guard
            let blur = CIFilter(name: "CIGaussianBlur",
                                parameters: [
                                    kCIInputImageKey: mask,
                                    kCIInputRadiusKey: 1.5 as NSNumber,
                                ])
        else { return mask }
        return blur.outputImage?.cropped(to: mask.extent) ?? mask
    }

    /// 마스크 반전 (0 ↔ 1)
    static func invertMask(_ mask: CIImage) -> CIImage? {
        guard let filter = CIFilter(name: "CIColorInvert") else { return nil }
        filter.setValue(mask, forKey: kCIInputImageKey)
        return filter.outputImage?.cropped(to: mask.extent)
    }
}
