import Metal

/// Undo/Redo 히스토리 — Hybrid 방식
/// 획 단위로 마스크 스냅샷 저장 (PNG 압축), 최대 maxHistory 단계
class EditHistory {
    private var snapshots: [Data] = []   // 압축된 마스크 스냅샷
    private var currentIndex: Int = -1
    private let maxHistory = 20

    var canUndo: Bool { currentIndex > 0 }
    var canRedo: Bool { currentIndex < snapshots.count - 1 }

    // 현재 마스크 상태를 히스토리에 추가
    func push(_ snapshot: Data) {
        // 현재 위치 이후의 redo 스택 제거
        if currentIndex < snapshots.count - 1 {
            snapshots.removeSubrange((currentIndex + 1)...)
        }

        snapshots.append(snapshot)

        // 최대 히스토리 초과 시 가장 오래된 항목 제거
        if snapshots.count > maxHistory {
            snapshots.removeFirst()
        }

        currentIndex = snapshots.count - 1
    }

    // Undo: 이전 스냅샷 반환
    func undo() -> Data? {
        guard canUndo else { return nil }
        currentIndex -= 1
        return snapshots[currentIndex]
    }

    // Redo: 다음 스냅샷 반환
    func redo() -> Data? {
        guard canRedo else { return nil }
        currentIndex += 1
        return snapshots[currentIndex]
    }

    func reset() {
        snapshots.removeAll()
        currentIndex = -1
    }
}
