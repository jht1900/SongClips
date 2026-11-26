//
//  PlaybackController.swift
//  SongClips
//
//  Plays a URL with AVPlayer into a PlaybackView (formerly PlaybackViewCtl,
//  based on Apple's AVPlayerDemo).
//

import AVFoundation
import Combine
import UIKit

protocol PlaybackControllerDelegate: AnyObject {
    func playbackController(_ controller: PlaybackController, seekCompletedAt time: TimeInterval)
    func playbackControllerDidReachEnd(_ controller: PlaybackController)
}

final class PlaybackController {
    weak var delegate: PlaybackControllerDelegate?

    private(set) var playbackView: PlaybackView?
    private(set) var url: URL?

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var itemObservers: Set<AnyCancellable> = []

    /// A seek requested before the item was ready, or still in progress.
    private var pendingSeek = false
    private var pendingSeekTime: TimeInterval = 0
    private var hasItem = false
    private var readyToPlay = false

    /// Show video in `view`, filling it.
    func attach(to view: PlaybackView?) {
        playbackView = view
        guard let view else { return }
        view.player = player
        view.videoGravity = .resizeAspectFill
    }

    /// Load `url` for playback. Requires a playback view.
    func load(_ newURL: URL) {
        guard playbackView != nil, newURL != url else { return }
        url = newURL
        let asset = AVURLAsset(url: newURL)
        Task {
            do {
                let (playable, _) = try await asset.load(.isPlayable, .tracks)
                guard url == newURL else { return }
                guard playable else {
                    showFailure(
                        title: "Item cannot be played",
                        reason: "The asset's tracks were loaded, but could not be made playable.")
                    return
                }
                prepareToPlay(asset)
            } catch {
                showFailure(title: error.localizedDescription, reason: (error as NSError).localizedFailureReason)
            }
        }
    }

    /// Stop playing and release the player. Call before discarding the controller.
    func invalidate() {
        itemObservers.removeAll()
        player?.pause()
    }

    func play() {
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    var isPlaying: Bool {
        (player?.rate ?? 0) != 0
    }

    /// Setting a rate on a paused player starts it playing.
    var rate: Float {
        get { player?.rate ?? 0 }
        set { player?.rate = newValue }
    }

    var currentTime: TimeInterval {
        get {
            if pendingSeek { return pendingSeekTime }
            let seconds = player?.currentTime().seconds ?? 0
            return seconds.isFinite ? seconds : 0
        }
        set {
            pendingSeek = true
            pendingSeekTime = newValue
            if hasItem { requestSeek() }
        }
    }

    private func requestSeek() {
        guard let player else { return }
        let target = pendingSeekTime
        player.seek(
            to: CMTime(seconds: target, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
            toleranceBefore: .zero, toleranceAfter: .zero
        ) { [weak self] finished in
            Task { @MainActor in
                guard let self else { return }
                self.pendingSeek = !finished
                if finished {
                    self.delegate?.playbackController(self, seekCompletedAt: target)
                }
            }
        }
    }

    private func prepareToPlay(_ asset: AVURLAsset) {
        itemObservers.removeAll()
        let item = AVPlayerItem(asset: asset)
        playerItem = item

        item.publisher(for: \.status, options: [.initial, .new])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in self?.statusChanged(status, item: item) }
            .store(in: &itemObservers)

        NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification, object: item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.delegate?.playbackControllerDidReachEnd(self)
            }
            .store(in: &itemObservers)

        if let player {
            player.replaceCurrentItem(with: item)
        } else {
            player = AVPlayer(playerItem: item)
        }
        attach(to: playbackView)
        hasItem = true
    }

    private func statusChanged(_ status: AVPlayerItem.Status, item: AVPlayerItem) {
        switch status {
        case .readyToPlay:
            readyToPlay = true
        case .failed:
            showFailure(title: item.error?.localizedDescription ?? "Playback failed", reason: nil)
        default:
            break
        }
        if readyToPlay && pendingSeek {
            requestSeek()
        }
    }

    private func showFailure(title: String, reason: String?) {
        appLog.error("Playback failed: \(title, privacy: .public)")
        Alerts.show(reason, title: title)
    }
}
