import Foundation
import MediaPlayer

/// Controla Now Playing y los mandos remotos (pantalla de bloqueo / auriculares)
/// para la lectura en voz alta. Los handlers los fija VoiceManager.
final class NowPlayingController {
    var onPlay: (() -> Void)?
    var onPause: (() -> Void)?
    var onStop: (() -> Void)?
    var isPlaying = false
    private var configured = false

    func configure() {
        guard !configured else { return }
        configured = true
        let cc = MPRemoteCommandCenter.shared()
        cc.playCommand.isEnabled = true
        cc.playCommand.addTarget { [weak self] _ in self?.onPlay?(); return .success }
        cc.pauseCommand.isEnabled = true
        cc.pauseCommand.addTarget { [weak self] _ in self?.onPause?(); return .success }
        cc.togglePlayPauseCommand.isEnabled = true
        cc.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            if self.isPlaying { self.onPause?() } else { self.onPlay?() }
            return .success
        }
        cc.stopCommand.isEnabled = true
        cc.stopCommand.addTarget { [weak self] _ in self?.onStop?(); return .success }
    }

    func update(text: String, elapsed: TimeInterval, duration: TimeInterval, rate: Float) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo =
            NowPlayingSupport.info(text: text, elapsed: elapsed, duration: duration, rate: rate)
    }

    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}