import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // applicationRegistrar를 통해 messenger/textures 직접 접근 (window 준비 여부 무관)
    let messenger = engineBridge.applicationRegistrar.messenger()
    let textures = engineBridge.applicationRegistrar.textures()

    ImageProcessingChannel.register(with: messenger)
    AISegmentationChannel.register(with: messenger)
    CameraChannel.register(with: messenger, textureRegistry: textures)
    ExportChannel.register(with: messenger)
    SoundChannel.register(with: messenger)
  }
}
