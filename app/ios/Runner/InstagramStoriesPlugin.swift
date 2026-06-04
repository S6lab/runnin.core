import Flutter
import UIKit

/// Bridge nativa pra Instagram Stories share via UIPasteboard.
///
/// O esquema `instagram-stories://share?source_application=BUNDLE_ID` só
/// importa o asset se a imagem estiver no UIPasteboard com a chave correta
/// (`com.instagram.sharedSticker.backgroundImage` ou `.stickerImage`) E com
/// `expirationDate` ≤ 5min. Sem isso o IG abre vazio.
///
/// Method: `shareToStories`
///   args:
///     - `imageBase64`: String — PNG data em base64 (background da story)
///     - `appId`: String — bundle id do app (source_application)
///   result: Bool — true se conseguiu abrir o IG, false se não está instalado
///           ou se falhou ao escrever no pasteboard.
@objc class InstagramStoriesPlugin: NSObject, FlutterPlugin {
  private static let channelName = "runnin/instagram_stories"

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName, binaryMessenger: registrar.messenger())
    let instance = InstagramStoriesPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "shareToStories":
      handleShareToStories(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleShareToStories(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let base64 = args["imageBase64"] as? String,
      let appId = args["appId"] as? String
    else {
      result(
        FlutterError(
          code: "bad_args", message: "imageBase64+appId required", details: nil))
      return
    }
    guard let imageData = Data(base64Encoded: base64) else {
      result(
        FlutterError(code: "decode_failed", message: "invalid base64", details: nil))
      return
    }
    guard let url = URL(string: "instagram-stories://share?source_application=\(appId)") else {
      result(false)
      return
    }
    guard UIApplication.shared.canOpenURL(url) else {
      // IG não instalado — caller cai pro action sheet genérico.
      result(false)
      return
    }
    let items: [[String: Any]] = [
      [
        "com.instagram.sharedSticker.backgroundImage": imageData
      ]
    ]
    let options: [UIPasteboard.OptionsKey: Any] = [
      .expirationDate: Date(timeIntervalSinceNow: 60 * 5)
    ]
    UIPasteboard.general.setItems(items, options: options)
    UIApplication.shared.open(url, options: [:]) { opened in
      result(opened)
    }
  }
}
