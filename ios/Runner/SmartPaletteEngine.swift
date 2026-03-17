import CoreImage
import Metal
import UIKit

// MARK: - 데이터 타입

/// AI 팔레트 추천 단일 항목
struct AISuggestionInfo {
    let id: String          // 고유 식별자
    let title: String       // 추천 제목 (한국어)
    let description: String // 설명 (한국어)
    let maskLabel: String   // 적용할 마스크 레이블 (detected object label)
    let colorHex: String    // 대표 색상 hex (#RRGGBB)
}

// MARK: - 엔진

/// AI 팔레트 추천 엔진
/// CIAreaAverage + HSL 히스토그램으로 채도 높은 상위 3개 색상 추천 카드를 생성한다
class SmartPaletteEngine {
    private let ciContext: CIContext

    init(device: MTLDevice) {
        ciContext = CIContext(mtlDevice: device, options: [.useSoftwareRenderer: false])
    }

    // MARK: - 추천 생성

    /// AI 추천 최대 3개 생성
    func generateSuggestions(
        from image: UIImage,
        detectedObjects: [DetectedObjectInfo],
        sceneLabels: [String: Float]
    ) -> [AISuggestionInfo] {
        var suggestions: [AISuggestionInfo] = []

        // 1. 인물 감지 → 인물 컬러 추천
        if detectedObjects.contains(where: { $0.label == "person" }) {
            suggestions.append(AISuggestionInfo(
                id: "suggest_person",
                title: "인물 컬러 살리기",
                description: "AI가 감지한 인물만 선명한 컬러로",
                maskLabel: "person",
                colorHex: "#FF6B9D"
            ))
        }

        // 2. 하늘 감지 → 하늘빛 추천
        let skyConf = sceneLabels.filter { $0.key.contains("sky") }.values.max() ?? 0
        if skyConf > 0.25 {
            suggestions.append(AISuggestionInfo(
                id: "suggest_sky",
                title: "하늘빛 살리기",
                description: "파란 하늘만 컬러로, 나머지는 흑백",
                maskLabel: "sky",
                colorHex: "#87CEEB"
            ))
        }

        // 3. 지배 색상 분석 → 색상 기반 추천 (아직 공간이 있을 때)
        if suggestions.count < 3 {
            let dominantColors = extractDominantColors(from: image)
            for colorInfo in dominantColors where suggestions.count < 3 {
                if colorInfo.saturation > 0.35 {
                    suggestions.append(AISuggestionInfo(
                        id: "suggest_color_\(colorInfo.hex)",
                        title: "\(colorInfo.korName) 살리기",
                        description: "\(colorInfo.korName) 계열 색상만 컬러로",
                        maskLabel: "color_\(colorInfo.hex.dropFirst())", // # 제거
                        colorHex: colorInfo.hex
                    ))
                }
            }
        }

        return Array(suggestions.prefix(3))
    }

    // MARK: - 색상 분석

    private struct DominantColorInfo {
        let hex: String
        let saturation: CGFloat
        let korName: String
    }

    private func extractDominantColors(from image: UIImage) -> [DominantColorInfo] {
        guard let ciImage = CIImage(image: image) else { return [] }

        let gridSize = 12
        let imageW = ciImage.extent.width
        let imageH = ciImage.extent.height
        let cellW = imageW / CGFloat(gridSize)
        let cellH = imageH / CGFloat(gridSize)

        guard let areaFilter = CIFilter(name: "CIAreaAverage") else { return [] }

        var hslSamples: [HSLColor] = []

        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let rect = CGRect(
                    x: CGFloat(col) * cellW,
                    y: CGFloat(row) * cellH,
                    width: cellW,
                    height: cellH
                )
                areaFilter.setValue(ciImage, forKey: kCIInputImageKey)
                areaFilter.setValue(CIVector(cgRect: rect), forKey: "inputExtent")

                guard
                    let output = areaFilter.outputImage,
                    let rgb = sampleAverageColor(from: output)
                else { continue }

                hslSamples.append(rgbToHSL(r: rgb.r, g: rgb.g, b: rgb.b))
            }
        }

        // 채도 높은 샘플만 Hue 60° 버킷으로 그룹화
        let saturated = hslSamples.filter { $0.saturation > 0.3 }
        guard !saturated.isEmpty else { return [] }

        var hueBuckets: [Int: [HSLColor]] = [:]
        for c in saturated {
            let bucket = Int(c.hue * 6) % 6
            hueBuckets[bucket, default: []].append(c)
        }

        return hueBuckets
            .sorted { $0.value.count > $1.value.count }
            .prefix(3)
            .compactMap { _, colors -> DominantColorInfo? in
                guard let rep = colors.max(by: { $0.saturation < $1.saturation }) else { return nil }
                let uiColor = hslToUIColor(hsl: rep)
                return DominantColorInfo(
                    hex: uiColor.hexString,
                    saturation: rep.saturation,
                    korName: koreanColorName(hue: rep.hue, saturation: rep.saturation)
                )
            }
    }

    // MARK: - 색상 공간 변환

    private struct HSLColor {
        let hue: CGFloat
        let saturation: CGFloat
        let lightness: CGFloat
    }

    private func sampleAverageColor(from ciImage: CIImage) -> (r: CGFloat, g: CGFloat, b: CGFloat)? {
        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(
            ciImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        return (CGFloat(bitmap[0]) / 255, CGFloat(bitmap[1]) / 255, CGFloat(bitmap[2]) / 255)
    }

    private func rgbToHSL(r: CGFloat, g: CGFloat, b: CGFloat) -> HSLColor {
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let l = (maxC + minC) / 2
        guard maxC != minC else { return HSLColor(hue: 0, saturation: 0, lightness: l) }

        let d = maxC - minC
        let s = l > 0.5 ? d / (2 - maxC - minC) : d / (maxC + minC)
        let h: CGFloat
        switch maxC {
        case r:  h = ((g - b) / d + (g < b ? 6 : 0)) / 6
        case g:  h = ((b - r) / d + 2) / 6
        default: h = ((r - g) / d + 4) / 6
        }
        return HSLColor(hue: h, saturation: s, lightness: l)
    }

    private func hslToUIColor(hsl: HSLColor) -> UIColor {
        func hue2rgb(_ p: CGFloat, _ q: CGFloat, _ t: CGFloat) -> CGFloat {
            var t = t
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1/6 { return p + (q - p) * 6 * t }
            if t < 1/2 { return q }
            if t < 2/3 { return p + (q - p) * (2/3 - t) * 6 }
            return p
        }
        if hsl.saturation == 0 {
            return UIColor(white: hsl.lightness, alpha: 1)
        }
        let q = hsl.lightness < 0.5
            ? hsl.lightness * (1 + hsl.saturation)
            : hsl.lightness + hsl.saturation - hsl.lightness * hsl.saturation
        let p = 2 * hsl.lightness - q
        return UIColor(
            red:   hue2rgb(p, q, hsl.hue + 1/3),
            green: hue2rgb(p, q, hsl.hue),
            blue:  hue2rgb(p, q, hsl.hue - 1/3),
            alpha: 1
        )
    }

    private func koreanColorName(hue: CGFloat, saturation: CGFloat) -> String {
        if saturation < 0.25 { return "무채색" }
        switch hue {
        case 0..<0.05, 0.93..<1.0: return "빨강"
        case 0.05..<0.11:          return "주황"
        case 0.11..<0.19:          return "황금빛"
        case 0.19..<0.29:          return "노랑"
        case 0.29..<0.42:          return "초록"
        case 0.42..<0.52:          return "민트"
        case 0.52..<0.62:          return "하늘색"
        case 0.62..<0.71:          return "파랑"
        case 0.71..<0.80:          return "남색"
        case 0.80..<0.87:          return "보라"
        case 0.87..<0.93:          return "자주"
        default:                   return "핑크"
        }
    }
}

// MARK: - UIColor 확장

private extension UIColor {
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X",
                      Int((r * 255).clamped(to: 0...255)),
                      Int((g * 255).clamped(to: 0...255)),
                      Int((b * 255).clamped(to: 0...255)))
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
