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

    // FlutterViewController를 통해 binaryMessenger 접근
    guard
      let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
      let rootVC = windowScene.windows.first?.rootViewController as? FlutterViewController
    else { return }

    ImageProcessingChannel.register(with: rootVC.binaryMessenger)
    AISegmentationChannel.register(with: rootVC.binaryMessenger)
    CameraChannel.register(with: rootVC.binaryMessenger, textureRegistry: rootVC)
  }
}
