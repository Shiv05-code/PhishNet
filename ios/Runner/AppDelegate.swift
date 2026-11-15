import Flutter
import MessageUI
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate,
  MFMessageComposeViewControllerDelegate
{
  /// Reply for the message composer that is currently open.
  private var pendingComposeResult: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "phishnet/message_composer",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "compose", let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.presentComposer(arguments: call.arguments as? [String: Any], result: result)
    }
  }

  private func presentComposer(arguments: [String: Any]?, result: @escaping FlutterResult) {
    guard MFMessageComposeViewController.canSendText() else {
      result("unavailable")
      return
    }
    guard pendingComposeResult == nil else {
      result("failed")
      return
    }
    guard let presenter = topViewController() else {
      result("failed")
      return
    }

    let composer = MFMessageComposeViewController()
    composer.messageComposeDelegate = self
    if let recipient = arguments?["recipient"] as? String {
      composer.recipients = [recipient]
    }
    composer.body = arguments?["body"] as? String

    if let logo = arguments?["logo"] as? FlutterStandardTypedData {
      composer.addAttachmentData(
        logo.data,
        typeIdentifier: "public.png",
        filename: "phishnet_share_logo.png"
      )
    }

    pendingComposeResult = result
    presenter.present(composer, animated: true)
  }

  func messageComposeViewController(
    _ controller: MFMessageComposeViewController,
    didFinishWith composeResult: MessageComposeResult
  ) {
    controller.dismiss(animated: true) {
      let status: String
      switch composeResult {
      case .sent: status = "sent"
      case .cancelled: status = "cancelled"
      default: status = "failed"
      }
      self.pendingComposeResult?(status)
      self.pendingComposeResult = nil
    }
  }

  /// The front-most view controller, so the composer appears above any open sheet.
  private func topViewController() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
    var top = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
      ?? window?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}
