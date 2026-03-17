import CoreImage
import UIKit

/// Core Image 기반 이미지 처리 엔진
/// GPU 가속을 활용하여 CPU 픽셀 루프를 사용하지 않는다
class ColorPopImageProcessor {

  // CIContext는 생성 비용이 크므로 싱글톤으로 재사용
  private static let ciContext = CIContext(options: [
    .useSoftwareRenderer: false,    // GPU 렌더링 강제
    .workingColorSpace: CGColorSpaceCreateDeviceRGB()
  ])

  // MARK: - 흑백 변환

  /// 이미지를 흑백으로 변환 (CIColorControls, saturation: 0)
  /// - Parameter imageData: 원본 이미지 Data (JPEG/PNG)
  /// - Returns: 흑백 처리된 JPEG Data, 실패 시 nil
  static func convertToGrayscale(imageData: Data) -> Data? {
    guard
      let uiImage = UIImage(data: imageData),
      let ciImage = CIImage(image: uiImage)
    else { return nil }

    // CIColorControls로 채도를 0으로 설정 → 흑백
    guard let filter = CIFilter(name: "CIColorControls") else { return nil }
    filter.setValue(ciImage, forKey: kCIInputImageKey)
    filter.setValue(0.0, forKey: kCIInputSaturationKey)
    filter.setValue(1.05, forKey: kCIInputBrightnessKey)  // 흑백 시 살짝 밝기 보정
    filter.setValue(1.1, forKey: kCIInputContrastKey)     // 흑백 시 대비 강조

    guard
      let outputImage = filter.outputImage,
      let cgImage = ciContext.createCGImage(outputImage, from: outputImage.extent)
    else { return nil }

    // 원본 방향 유지
    let resultImage = UIImage(cgImage: cgImage, scale: uiImage.scale, orientation: uiImage.imageOrientation)
    return resultImage.jpegData(compressionQuality: 0.92)
  }

  // MARK: - Phase 2+에서 추가될 메서드 (인터페이스 예약)

  // static func blendWithMask(color: CIImage, mask: CIImage) -> Data? { ... }
  // static func selectColorRange(image: CIImage, hue: Float, tolerance: Float) -> Data? { ... }
  // static func applyNeonGlow(image: CIImage, intensity: Float) -> Data? { ... }
}
