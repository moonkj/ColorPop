import AudioToolbox
import UIKit

/// iOS 시스템 사운드 + 햅틱 피드백 엔진
/// 마이크로 인터랙션 사운드 디자인 (B-12)
class SoundEngine {

    // MARK: - 사운드 ID (iOS 내장 시스템 사운드)

    /// 선택/탭 — 짧고 밝은 틱
    private static let soundTick: SystemSoundID = 1104

    /// AI 완료 — 부드러운 차임
    private static let soundChime: SystemSoundID = 1022

    /// 저장/성공 — 만족감 있는 팝
    private static let soundPop: SystemSoundID = 1057

    /// 공유/전송 — 가벼운 날개
    private static let soundSend: SystemSoundID = 1003

    /// 에러 — 짧은 버즈
    private static let soundError: SystemSoundID = 1073

    // MARK: - 공개 API

    /// 브러시 첫 획 시작 — 가벼운 틱
    static func playBrushStart() {
        AudioServicesPlaySystemSound(soundTick)
    }

    /// AI 세그멘테이션 완료 — 차임
    static func playAiComplete() {
        AudioServicesPlaySystemSound(soundChime)
    }

    /// 저장 성공 — 팝
    static func playSaveSuccess() {
        AudioServicesPlaySystemSound(soundPop)
    }

    /// 공유 성공 — 전송 사운드
    static func playShareSuccess() {
        AudioServicesPlaySystemSound(soundSend)
    }

    /// 에러 발생
    static func playError() {
        AudioServicesPlaySystemSound(soundError)
    }

    /// 색상 선택 — 틱
    static func playColorSelect() {
        AudioServicesPlaySystemSound(soundTick)
    }

    // MARK: - 진동 햅틱 (native)

    /// 가벼운 임팩트
    static func lightImpact() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// 중간 임팩트
    static func mediumImpact() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// 강한 임팩트
    static func heavyImpact() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    /// 성공 알림 (3연타 경쾌한 진동)
    static func notifySuccess() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// 에러 알림
    static func notifyError() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    /// 선택 변경 (탭 피드백)
    static func selectionChanged() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
