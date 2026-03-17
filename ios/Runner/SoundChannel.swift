import Flutter
import UIKit

/// ColorPop Sound + Haptic Platform Channel
/// com.colorpop/sound
class SoundChannel {
    static let channelName = "com.colorpop/sound"

    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)

        channel.setMethodCallHandler { call, result in
            switch call.method {

            // ── 사운드 ─────────────────────────────────────────────
            case "playBrushStart":
                SoundEngine.playBrushStart()
                result(nil)

            case "playAiComplete":
                SoundEngine.playAiComplete()
                result(nil)

            case "playSaveSuccess":
                SoundEngine.playSaveSuccess()
                result(nil)

            case "playShareSuccess":
                SoundEngine.playShareSuccess()
                result(nil)

            case "playError":
                SoundEngine.playError()
                result(nil)

            case "playColorSelect":
                SoundEngine.playColorSelect()
                result(nil)

            // ── 햅틱 ──────────────────────────────────────────────
            case "lightImpact":
                SoundEngine.lightImpact()
                result(nil)

            case "mediumImpact":
                SoundEngine.mediumImpact()
                result(nil)

            case "heavyImpact":
                SoundEngine.heavyImpact()
                result(nil)

            case "notifySuccess":
                SoundEngine.notifySuccess()
                result(nil)

            case "notifyError":
                SoundEngine.notifyError()
                result(nil)

            case "selectionChanged":
                SoundEngine.selectionChanged()
                result(nil)

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}
