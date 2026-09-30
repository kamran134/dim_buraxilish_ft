import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  // Outcome of APNs registration, read by Dart (az.dim.buraxilish/apns → "status")
  // for the push diagnostics line on the settings screen.
  private var apnsState: [String: String] = ["state": "pending"]

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let registrar = registrar(forPlugin: "ApnsDiagnostics") {
      let channel = FlutterMethodChannel(
        name: "az.dim.buraxilish/apns", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "status" else {
          result(FlutterMethodNotImplemented)
          return
        }
        result(self?.apnsState)
      }
    }

    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    // firebase_messaging also does this on launch; calling it here as well makes
    // registration independent of the plugin's launch-notification observer.
    application.registerForRemoteNotifications()
    return launched
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    apnsState = ["state": "registered"]
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    // Hand the token to Firebase directly as well, in case the plugin's
    // app-delegate forwarding/swizzling did not. Done through the ObjC runtime
    // so the Runner target needs no FirebaseMessaging import (plugins come via SPM).
    if let messagingClass = NSClassFromString("FIRMessaging") as? NSObject.Type,
      let messaging = messagingClass.perform(NSSelectorFromString("messaging"))?
        .takeUnretainedValue() as? NSObject
    {
      messaging.setValue(deviceToken, forKey: "APNSToken")
    } else {
      apnsState["error"] = "FIRMessaging class not found"
    }
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    apnsState = ["state": "failed", "error": error.localizedDescription]
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}
