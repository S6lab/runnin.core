// TF 75 Fase 0 (CRÍTICO): mantém a AVAudioSession ATIVA o tempo todo
// durante a corrida via silent audio loop. Sem isso, `UIBackgroundMode=audio`
// só protege o Dart engine ENQUANTO o coach está falando (3-10s por cue),
// e entre falas o iOS suspende o app. Resultado: BPM iPhone trava, cues
// param, telemetria não chega. Eduardo TF 74: "cues param após 5min de tela
// bloqueada".
//
// Solução: AVAudioEngine emite buffer de silêncio (volume 0) em loop. Apple
// reconhece como "audio playing" e mantém o app vivo até o fim da run.
//
// Custo: ~3-5% bateria extra/h. Aceitável pra fitness app.

import AVFoundation
import Flutter
import Foundation
import OSLog

private let asLog = OSLog(subsystem: "ai.runnin.audio_session", category: "audio-keepalive")

@objc class RunninAudioKeepalivePlugin: NSObject, FlutterPlugin {
  private static let channelName = "runnin/audio_session"
  private var engine: AVAudioEngine?
  private var sourceNode: AVAudioSourceNode?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = RunninAudioKeepalivePlugin()
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startKeepalive":
      startKeepalive(result: result)
    case "stopKeepalive":
      stopKeepalive(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func startKeepalive(result: @escaping FlutterResult) {
    if engine != nil {
      // Já rodando — idempotente.
      result(["ok": true, "reason": "already_running"])
      return
    }

    do {
      // .playback com .mixWithOthers permite Spotify/Apple Music continuar.
      // .duckOthers abaixa quando coach fala (já é o comportamento default
      // do audioplayers do Dart, mas reforçamos aqui pra silent loop não
      // mudar nada).
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(
        .playback,
        mode: .voiceChat,
        options: [.mixWithOthers, .duckOthers]
      )
      try session.setActive(true, options: [])

      // AVAudioEngine + sourceNode emitindo silêncio. Não precisa de arquivo
      // — gera buffer zero on-the-fly. iOS conta como "playing audio".
      let eng = AVAudioEngine()
      let format = AVAudioFormat(
        standardFormatWithSampleRate: 44100,
        channels: 2
      )!
      let src = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
        let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
        for buffer in ablPointer {
          memset(buffer.mData, 0, Int(buffer.mDataByteSize))
        }
        return noErr
      }
      eng.attach(src)
      eng.connect(src, to: eng.mainMixerNode, format: format)
      eng.mainMixerNode.outputVolume = 0.0

      try eng.start()

      engine = eng
      sourceNode = src
      os_log("keepalive.started", log: asLog, type: .info)
      result(["ok": true])
    } catch {
      os_log("keepalive.start_failed err=%{public}@", log: asLog, type: .error,
             error.localizedDescription)
      result(["ok": false, "error": error.localizedDescription])
    }
  }

  private func stopKeepalive(result: @escaping FlutterResult) {
    if let src = sourceNode, let eng = engine {
      eng.disconnectNodeInput(src)
      eng.detach(src)
    }
    engine?.stop()
    engine = nil
    sourceNode = nil
    // NÃO chamamos setActive(false) — o audioplayers do Dart pode ainda
    // estar consumindo (último cue da fila ainda tocando). Deixa AVAudioSession
    // se desativar naturalmente quando todos os players terminarem.
    os_log("keepalive.stopped", log: asLog, type: .info)
    result(["ok": true])
  }
}
