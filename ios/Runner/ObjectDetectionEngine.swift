import Vision
import UIKit

// MARK: - 데이터 타입

/// 객체 마스크 생성 방식
enum ObjectMaskType: String {
    case person      // 전체 인물 세그멘테이션 마스크
    case boundingBox // 바운딩 박스 기반 마스크
    case topRegion   // 화면 상단 영역 (하늘)
    case inverted    // 인물 마스크 반전 (배경 전체 선택)
}

/// Vision 감지 결과 단일 객체
struct DetectedObjectInfo: Equatable {
    let label: String       // 영문 식별자 ("person", "face", "sky" ...)
    let korLabel: String    // 한국어 레이블
    let confidence: Float
    let boundingBox: CGRect // Vision 정규화 좌표 (원점=좌하단, 0~1)
    let maskType: ObjectMaskType
}

// MARK: - 엔진

/// Vision 프레임워크 기반 객체/장면 감지 엔진
class ObjectDetectionEngine {

    // MARK: - 메인 감지

    /// 이미지에서 객체를 감지한다
    /// 감지된 모든 객체를 중복 없이 반환하며, 인물이 있을 경우 "배경 전체" 칩을 추가한다
    func detectObjects(from image: UIImage) async -> [DetectedObjectInfo] {
        guard let cgImage = image.cgImage else { return [] }

        var results: [DetectedObjectInfo] = []

        // 인체 감지 (person 마스크 타입 → 세그멘테이션 사용)
        if let humans = detectHumans(cgImage: cgImage) {
            results.append(contentsOf: humans)
        }
        // 얼굴 감지
        if let faces = detectFaces(cgImage: cgImage) {
            results.append(contentsOf: faces)
        }
        // 동물 감지 (iOS 14+)
        if #available(iOS 14.0, *) {
            if let animals = detectAnimals(cgImage: cgImage) {
                results.append(contentsOf: animals)
            }
        }
        // 씬 분류 기반 객체 (하늘 등)
        if let sceneObjects = detectFromScene(cgImage: cgImage) {
            results.append(contentsOf: sceneObjects)
        }

        // 인물이 감지된 경우 "배경 전체" 칩 추가
        if results.contains(where: { $0.label == "person" }) {
            results.append(DetectedObjectInfo(
                label: "nonSubject",
                korLabel: "배경 전체",
                confidence: 1.0,
                boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1),
                maskType: .inverted
            ))
        }

        return deduplicateByLabel(results)
    }

    // MARK: - 씬 분류 (SmartPalette에서 재사용)

    /// VNClassifyImageRequest로 씬 레이블과 신뢰도를 반환한다
    func classifyScene(from image: UIImage) -> [String: Float] {
        guard let cgImage = image.cgImage else { return [:] }
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        guard (try? handler.perform([request])) != nil,
              let observations = request.results
        else { return [:] }

        var result: [String: Float] = [:]
        observations.filter { $0.confidence > 0.05 }.forEach {
            result[$0.identifier] = $0.confidence
        }
        return result
    }

    // MARK: - 개별 감지 메서드 (동기)

    private func detectHumans(cgImage: CGImage) -> [DetectedObjectInfo]? {
        let request = VNDetectHumanRectanglesRequest()
        request.upperBodyOnly = false
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        guard (try? handler.perform([request])) != nil,
              let observations = request.results,
              !observations.isEmpty
        else { return nil }

        // 가장 큰 인체 1개만 (세그멘테이션 마스크 사용)
        guard let largest = observations.max(by: { $0.boundingBox.area < $1.boundingBox.area })
        else { return nil }

        return [DetectedObjectInfo(
            label: "person",
            korLabel: "인물",
            confidence: largest.confidence,
            boundingBox: largest.boundingBox,
            maskType: .person
        )]
    }

    private func detectFaces(cgImage: CGImage) -> [DetectedObjectInfo]? {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        guard (try? handler.perform([request])) != nil,
              let observations = request.results,
              !observations.isEmpty
        else { return nil }

        return [DetectedObjectInfo(
            label: "face",
            korLabel: "얼굴",
            confidence: observations[0].confidence,
            boundingBox: observations[0].boundingBox,
            maskType: .boundingBox
        )]
    }

    @available(iOS 14.0, *)
    private func detectAnimals(cgImage: CGImage) -> [DetectedObjectInfo]? {
        let request = VNRecognizeAnimalsRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        guard (try? handler.perform([request])) != nil,
              let observations = request.results,
              !observations.isEmpty
        else { return nil }

        return observations.compactMap { obs -> DetectedObjectInfo? in
            guard let topLabel = obs.labels.first else { return nil }
            return DetectedObjectInfo(
                label: topLabel.identifier,
                korLabel: koreanAnimalName(topLabel.identifier),
                confidence: obs.confidence,
                boundingBox: obs.boundingBox,
                maskType: .boundingBox
            )
        }
    }

    private func detectFromScene(cgImage: CGImage) -> [DetectedObjectInfo]? {
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        guard (try? handler.perform([request])) != nil,
              let observations = request.results
        else { return nil }

        var objects: [DetectedObjectInfo] = []

        // 하늘: 상단 40% 영역을 마스크 영역으로 사용
        let skyConf = observations
            .filter { $0.identifier.contains("sky") }
            .map(\.confidence)
            .max() ?? 0
        if skyConf > 0.25 {
            objects.append(DetectedObjectInfo(
                label: "sky",
                korLabel: "하늘",
                confidence: skyConf,
                boundingBox: CGRect(x: 0, y: 0.6, width: 1.0, height: 0.4), // Vision: 위쪽이 높은 y
                maskType: .topRegion
            ))
        }

        return objects.isEmpty ? nil : objects
    }

    // MARK: - 유틸

    private func deduplicateByLabel(_ items: [DetectedObjectInfo]) -> [DetectedObjectInfo] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.label).inserted }
    }

    private func koreanAnimalName(_ identifier: String) -> String {
        ["cat": "고양이", "dog": "강아지", "horse": "말",
         "bird": "새", "rabbit": "토끼", "bear": "곰"][identifier] ?? "동물"
    }
}

// MARK: - CGRect 확장

private extension CGRect {
    var area: CGFloat { width * height }
}
