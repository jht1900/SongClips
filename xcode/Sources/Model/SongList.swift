//
//  SongList.swift
//  SongClips
//
//  Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
//
//  The user's songs, and playback of the current song with clip-aware play modes.
//  Music library songs play with MPMusicPlayerController; video, local files and
//  streams play with AVPlayer. Songs with no media play on a simulated clock.
//

import MediaPlayer
import UIKit

/// What happens when playback reaches the end of a clip.
enum ClipPlayMode: Int, CaseIterable {
    case none = 0
    case `continue`
    case `repeat`
    case pause
    case pauseThenContinue
    case pauseThenRepeat

    var title: String {
        switch self {
        case .none: ""
        case .continue: "Continue"
        case .repeat: "Repeat"
        case .pause: "Pause"
        case .pauseThenContinue: "Pause then Continue"
        case .pauseThenRepeat: "Pause then Repeat"
        }
    }
}

/// Receives playback updates from `SongList`.
protocol SongListWatcher: AnyObject {
    func timeReport(_ newTime: TimeInterval)
    func reportSongChange()
    /// True while the user drags the scrubber; play-mode handling waits until they let go.
    var isTracking: Bool { get }
}

final class SongList {
    static let shared = SongList()

    /// Keys in app.plist. These must not change: existing user data depends on them.
    private enum Key {
        static let songFileNames = "kSongFileNameArrayKey"
        static let nextSongID = "kNextSongIDKey"
    }

    private static let timerInterval: TimeInterval = 0.1
    /// How often the play position is written to preferences.
    private static let syncUpdateInterval: TimeInterval = 1.0
    /// "Previous" within this many seconds of a clip's start goes to the previous clip,
    /// otherwise it restarts the current clip.
    private static let previousClipRestartWindow: TimeInterval = 1.0

    weak var delegate: SongListWatcher?

    private(set) var avPlayerCtl: PlaybackController? {
        willSet {
            if newValue !== avPlayerCtl { avPlayerCtl?.invalidate() }
        }
    }
    private(set) var playbackView: PlaybackView?
    let musicPlayer: MPMusicPlayerController
    let imageCache = ImageCache(allowance: AppConfig.maxCacheImages)
    let imageIconCache = ImageCache(allowance: AppConfig.maxCacheImageIcons)

    private(set) var useAVPlayer = false
    var dirty = false

    private var songs: [Song] = []
    private var nextSongID = 0
    private(set) var currentSongIndex = 0
    private var updateTimer: Timer?

    private var clipStartTime: TimeInterval = 0
    private var lastTimeSync: TimeInterval = 0
    private var lastCurrentPlayTimeSync: TimeInterval = 0

    // Songs with no media play on a simulated clock.
    private var missingMediaItem = false
    private var missingMediaIsPlaying = false
    private var missingMediaOffsetTime: TimeInterval = 0
    private var missingMediaCurrentTime: TimeInterval = 0

    private var lastClipIndex = 0
    private var lastClipStart: TimeInterval = 0
    private var lastClipDuration: TimeInterval = 0

    /// Paused at the end of a clip by a pause play mode.
    private var playModePause = false
    private var playModePauseOffsetTime: TimeInterval = 0

    /// After a seek the player can briefly report a time just before the target;
    /// while this is set, report the target instead so the clip display does not flicker.
    private var seekIssuedDuringPlay = false
    private var seekIssuedDuringPlayTime: TimeInterval = 0

    private var userDefaultsSyncNeeded = false
    private var playRequested = false

    private var speedShiftEnabled = false
    private var speedShiftStartTime: TimeInterval = 0
    private var speedShiftIndex = 0

    private var now: TimeInterval { Date.timeIntervalSinceReferenceDate }

    private init() {
        if UserDefaults.standard.bool(forKey: DefaultsKey.playerTypePreference) {
            musicPlayer = .systemMusicPlayer
            if musicPlayer.nowPlayingItem != nil { musicPlayer.repeatMode = .none }
        } else {
            musicPlayer = .applicationMusicPlayer
            musicPlayer.shuffleMode = .off
            musicPlayer.repeatMode = .none
        }
        let nc = NotificationCenter.default
        nc.addObserver(
            self, selector: #selector(nowPlayingItemChanged),
            name: .MPMusicPlayerControllerNowPlayingItemDidChange, object: musicPlayer)
        nc.addObserver(
            self, selector: #selector(playbackStateChanged),
            name: .MPMusicPlayerControllerPlaybackStateDidChange, object: musicPlayer)
        nc.addObserver(self, selector: #selector(willResignActive), name: UIScene.willDeactivateNotification, object: nil)
        nc.addObserver(self, selector: #selector(becomeActive), name: UIScene.didActivateNotification, object: nil)
        musicPlayer.beginGeneratingPlaybackNotifications()
    }

    // MARK: Delegate

    /// Make `watcher` receive updates and show video in `view`.
    func setDelegate(_ watcher: SongListWatcher?, view: PlaybackView?) {
        delegate = watcher
        playbackView = view
        view?.isHidden = !useAVPlayer
        setupSong(at: currentSongIndex)
    }

    func reportSongChange() {
        delegate?.reportSongChange()
    }

    // MARK: App lifecycle

    @objc private func willResignActive() {
        // clipStartTime is reported while the music player is inactive.
        clipStartTime = lastCurrentPlayTimeSync
        checkPrefSync()
        if dirty { saveToDisk() }
        updateTimer?.invalidate()
        updateTimer = nil
    }

    @objc private func becomeActive() {
        resumeSongSettings()
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: Self.timerInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.reportCurrentTime() }
        }
    }

    // MARK: Remembered settings

    private func saveTimeToPrefs(_ time: TimeInterval) {
        lastCurrentPlayTimeSync = time
        let defaults = UserDefaults.standard
        defaults.set(time, forKey: DefaultsKey.songCurrentTime)
        defaults.set(playMode.rawValue, forKey: DefaultsKey.songPlayMode)
        userDefaultsSyncNeeded = true
    }

    /// Save the current song's position if it changed.
    private func checkPrefSync() {
        guard userDefaultsSyncNeeded else { return }
        if let song = currentSong, song.currentPos != lastCurrentPlayTimeSync {
            song.currentPos = lastCurrentPlayTimeSync
            song.saveToDisk()
        }
        userDefaultsSyncNeeded = false
    }

    private func clearRememberedSettings() {
        UserDefaults.standard.removeObject(forKey: DefaultsKey.songCurrentTime)
        userDefaultsSyncNeeded = true
        clipStartTime = 0
    }

    private func rememberCurrentSongIndex() {
        UserDefaults.standard.set(currentSongIndex, forKey: DefaultsKey.songCurrentIndex)
        userDefaultsSyncNeeded = true
    }

    private func resumeSongSettings() {
        let defaults = UserDefaults.standard
        let index = defaults.integer(forKey: DefaultsKey.songCurrentIndex)
        let time = defaults.double(forKey: DefaultsKey.songCurrentTime)
        var mode = ClipPlayMode(rawValue: defaults.integer(forKey: DefaultsKey.songPlayMode)) ?? .none
        if mode == .none { mode = .repeat }
        setupSong(at: index)
        setCurrentTimeOnPlayer(time)
        applyPlayMode(mode)
    }

    // MARK: Choosing the song

    private func setupSong(at index: Int) {
        if index >= songCount {
            musicPlayer.stop()
        } else {
            let song = song(at: index)
            missingMediaItem = song.mediaItem == nil && !(song.sourceForLocal != nil && song.url != nil)
            if missingMediaItem {
                avPlayerCtl?.playbackView?.isHidden = true
                useAVPlayer = false
                avPlayerCtl = nil
                musicPlayer.stop()
            } else if let url = song.url {
                useAVPlayer = true
                let oldTime = avPlayerCtl?.currentTime ?? 0
                let controller = PlaybackController()
                avPlayerCtl = controller
                controller.delegate = self
                controller.attach(to: playbackView)
                controller.load(url)
                controller.playbackView?.isHidden = false
                controller.currentTime = oldTime
            } else if let item = song.mediaItem {
                useAVPlayer = false
                avPlayerCtl?.playbackView?.isHidden = true
                avPlayerCtl = nil
                if musicPlayer.nowPlayingItem != item {
                    musicPlayer.setQueue(with: MPMediaItemCollection(items: [item]))
                }
            }
        }
        currentSongIndex = index
        reportSongChange()
    }

    private func setupSongAndRemember(at index: Int) {
        setupSong(at: index)
        rememberCurrentSongIndex()
    }

    /// Make `song` current and move to its remembered position.
    func selectSong(_ song: Song) {
        checkPrefSync()
        guard let index = songs.firstIndex(where: { $0 === song }) else { return }
        setupSongAndRemember(at: index)
        currentTime = song.currentPos < song.duration ? song.currentPos : 0
        clipStartTime = currentTime
    }

    var currentSong: Song? {
        songs.indices.contains(currentSongIndex) ? songs[currentSongIndex] : nil
    }

    var currentClipIndex: Int {
        currentSong?.clipIndex(for: currentTime) ?? 0
    }

    var isVideo: Bool { useAVPlayer }

    // MARK: Song storage

    var songCount: Int { songs.count }

    /// The song at `index`, read from disk on first access.
    func song(at index: Int) -> Song {
        let song = songs[index]
        if song.title == nil {
            song.restoreFromDisk()
        }
        return song
    }

    func moveSong(from fromIndex: Int, to toIndex: Int) {
        let song = songs.remove(at: fromIndex)
        songs.insert(song, at: toIndex)
        saveToDisk()
    }

    func removeSong(at index: Int) {
        let song = songs[index]
        if song.storeName != nil {
            try? FileManager.default.removeItem(at: song.directoryURL)
        }
        songs.remove(at: index)

        if currentSongIndex == index {
            musicPlayer.stop()
            if currentSongIndex >= songCount { currentSongIndex = 0 }
            clearRememberedSettings()
            setupSongAndRemember(at: currentSongIndex)
        } else if currentSongIndex > index {
            currentSongIndex -= 1
            rememberCurrentSongIndex()
        }
        saveToDisk()
    }

    func saveToDisk() {
        let dict: [String: Any] = [
            Key.nextSongID: nextSongID,
            Key.songFileNames: songs.map { $0.storeName ?? "" },
        ]
        Storage.createDirectory(Storage.rootURL)
        Storage.writePlist(dict, to: Storage.rootURL.appendingPathComponent(StoreFile.appPlist))
        dirty = false
    }

    /// Load the song list from disk and restore the last song and position.
    func resumeFromDisk() {
        if let dict = Storage.readPlist(at: Storage.rootURL.appendingPathComponent(StoreFile.appPlist)) {
            nextSongID = (dict[Key.nextSongID] as? NSNumber)?.intValue ?? 0
            // Placeholder songs: only the folder name is set until the song is first used.
            for name in dict[Key.songFileNames] as? [String] ?? [] {
                let song = Song()
                song.storeName = name
                songs.append(song)
            }
        }
        resumeSongSettings()
    }

    /// Create a song from a text export or JSON, or re-import into `existing`.
    @discardableResult
    func importSong(from string: String, into existing: Song?) -> Song {
        let song = existing ?? Song()
        song.load(fromExport: string)
        if existing == nil {
            songs.append(song)
        }
        saveToDisk()
        return song
    }

    func addSong(for mediaItem: MPMediaItem) {
        songs.append(Song.make(mediaItem: mediaItem))
        saveToDisk()
    }

    func addSongs(from collection: MPMediaItemCollection) {
        songs.append(contentsOf: collection.items.map(Song.make(mediaItem:)))
        saveToDisk()
    }

    /// Next song folder name, e.g. "12-MySong".
    func nextSongFileName(prefix: String?) -> String {
        var safe = (prefix ?? "").replacingOccurrences(of: "/", with: "").replacingOccurrences(of: " ", with: "")
        if safe.count > 32 { safe = String(safe.prefix(32)) }
        defer {
            nextSongID += 1
            dirty = true
        }
        return "\(nextSongID)-\(safe)"
    }

    // MARK: Playback

    var isPlaying: Bool {
        if missingMediaItem { return missingMediaIsPlaying }
        if useAVPlayer { return avPlayerCtl?.isPlaying ?? false }
        return musicPlayer.playbackState == .playing
    }

    func play() {
        guard let song = currentSong else { return }

        speedShiftEnabled = song.speedShiftList != nil
        if speedShiftEnabled {
            speedShiftStartTime = now
            speedShiftIndex = 0
            speedShiftMonitor(song)
        }

        if playModePause && !isPlaying {
            if playMode != .pause { establishNextClip() }
            playModePause = false
        }

        if missingMediaItem {
            if !missingMediaIsPlaying {
                missingMediaOffsetTime = now - missingMediaCurrentTime
                missingMediaIsPlaying = true
            }
            return
        } else if useAVPlayer {
            avPlayerCtl?.play()
        } else {
            if musicPlayer.nowPlayingItem == nil {
                // The music player dropped the current song; set it up again.
                setupSongAndRemember(at: currentSongIndex)
                musicPlayer.currentPlaybackTime = clipStartTime
            }
            musicPlayer.play()
        }
        playRequested = true
    }

    func pause() {
        if missingMediaItem {
            if missingMediaIsPlaying {
                missingMediaCurrentTime = now - missingMediaOffsetTime
                missingMediaIsPlaying = false
                clipStartTime = missingMediaCurrentTime
            }
        } else if useAVPlayer {
            avPlayerCtl?.pause()
        } else {
            if musicPlayer.playbackState == .playing {
                // Remember where we paused.
                clipStartTime = musicPlayer.currentPlaybackTime
            }
            musicPlayer.pause()
        }
        playRequested = false
    }

    /// Change the playback rate. Only AVPlayer playback supports this.
    func setCurrentRate(_ rate: Float) {
        if useAVPlayer {
            avPlayerCtl?.rate = rate
        }
    }

    func setClipStartTime(_ time: TimeInterval) {
        clipStartTime = time
    }

    /// The current play position. Setting it seeks, remembers the position and selects the clip.
    var currentTime: TimeInterval {
        get {
            if playModePause && (playMode == .pauseThenContinue || playMode == .pauseThenRepeat) {
                // The pause between clips runs on the clock.
                return now - playModePauseOffsetTime
            }
            if missingMediaItem {
                return missingMediaIsPlaying ? now - missingMediaOffsetTime : missingMediaCurrentTime
            }
            var time = useAVPlayer ? (avPlayerCtl?.currentTime ?? 0) : musicPlayer.currentPlaybackTime
            if seekIssuedDuringPlay && seekIssuedDuringPlayTime > time {
                time = seekIssuedDuringPlayTime
            }
            return time
        }
        set {
            setCurrentTimeOnPlayer(newValue)
            saveTimeToPrefs(newValue)
            if playRequested { markSeek(to: newValue) }
            establishClip(at: currentSong?.clipIndex(for: newValue) ?? 0)
        }
    }

    private func setCurrentTimeOnPlayer(_ time: TimeInterval) {
        if missingMediaItem {
            if missingMediaIsPlaying {
                missingMediaOffsetTime = now - time
            } else {
                missingMediaCurrentTime = time
            }
            clipStartTime = time
            return
        } else if useAVPlayer {
            avPlayerCtl?.currentTime = time
        } else {
            if musicPlayer.nowPlayingItem == nil {
                // The music player dropped the current song; set it up again.
                setupSong(at: currentSongIndex)
            }
            musicPlayer.currentPlaybackTime = time
        }
        clipStartTime = time
        seekIssuedDuringPlay = false
    }

    /// Apply the song's timed rate changes.
    func speedShiftMonitor(_ song: Song) {
        guard speedShiftEnabled, let list = song.speedShiftList, !list.isEmpty else { return }
        if !list.indices.contains(speedShiftIndex) { speedShiftIndex = 0 }
        let entry = list[speedShiftIndex]
        let duration = (entry["duration"] as? NSNumber)?.doubleValue ?? 0
        guard duration != 0, now - speedShiftStartTime >= duration else { return }
        speedShiftStartTime = now
        speedShiftIndex += 1
        let rate = (entry["rate"] as? NSNumber)?.floatValue ?? 0
        guard rate != 0 else { return }
        setCurrentRate(rate)
    }

    // MARK: Clips

    private(set) var playMode: ClipPlayMode = .none

    private func applyPlayMode(_ mode: ClipPlayMode) {
        playMode = mode
        playModePause = false
        establishClip(at: currentClipIndex)
        _ = handlePlayMode(at: currentTime)
    }

    /// Change the play mode. It is remembered across launches.
    func setPlayMode(_ mode: ClipPlayMode) {
        applyPlayMode(mode)
        userDefaultsSyncNeeded = true
    }

    func establishClipForCurrentTime() {
        establishClip(at: currentClipIndex)
    }

    /// Make clip `index` the clip that play modes act on, and apply its playback rate.
    func establishClip(at index: Int) {
        lastClipIndex = index
        let clip = currentSong?.clip(at: index)
        lastClipStart = clip?.startTime ?? 0
        lastClipDuration = clip?.subDuration ?? 0
        if let rate = clip?.clipRate, rate != 0 {
            setCurrentRate(Float(rate))
        }
    }

    private func establishNextClip() {
        guard let song = currentSong else { return }
        if lastClipIndex < song.clipCount - 1 {
            lastClipIndex += 1
        }
        let clip = song.clip(at: lastClipIndex)
        lastClipStart = clip?.startTime ?? 0
        lastClipDuration = clip?.subDuration ?? 0
    }

    func nextClip() {
        var index = currentClipIndex
        var playNeeded = false
        if playModePause {
            playModePause = false
            play()
            index = lastClipIndex
            playNeeded = true
        }
        guard let song = currentSong, index < song.clipCount - 1,
            let next = song.clip(at: index + 1)
        else { return }
        jump(to: next.startTime)
        if playNeeded { play() }
        // In pause mode the next clip sometimes gets stuck without this.
        markSeek(to: next.startTime)
    }

    func previousClip() {
        if !playModePause && currentTime > lastClipStart + Self.previousClipRestartWindow {
            setCurrentTimeOnPlayer(lastClipStart)
            return
        }
        var index = currentClipIndex
        var playNeeded = false
        if playModePause {
            playModePause = false
            play()
            index = lastClipIndex
            playNeeded = true
        }
        guard let song = currentSong, index >= 0 else { return }
        if index > 0 { index -= 1 }
        jump(to: song.clip(at: index)?.startTime ?? 0)
        if playNeeded { play() }
    }

    private func jump(to time: TimeInterval) {
        currentTime = time
        delegate?.timeReport(time)
    }

    private func markSeek(to time: TimeInterval) {
        seekIssuedDuringPlay = true
        seekIssuedDuringPlayTime = time
    }

    /// Apply the play mode when playback passes the end of the current clip.
    /// Returns the time to report, which changes when playback jumps.
    private func handlePlayMode(at time: TimeInterval) -> TimeInterval {
        let clipEnd = lastClipStart + lastClipDuration
        guard time >= clipEnd else { return time }
        switch playMode {
        case .none, .continue:
            return time
        case .repeat:
            currentTime = lastClipStart
            markSeek(to: lastClipStart)
            return lastClipStart
        case .pause:
            pause()
            playModePause = true
            return time
        case .pauseThenContinue:
            if !playModePause {
                pause()
                playModePause = true
                playModePauseOffsetTime = now - lastClipStart
            } else {
                // The pause, timed as long as the clip, is over.
                if lastClipIndex < (currentSong?.clipCount ?? 0) - 1 {
                    establishNextClip()
                } else {
                    currentTime = 0
                }
                playModePause = false
                play()
            }
            return time
        case .pauseThenRepeat:
            if !playModePause {
                pause()
                playModePause = true
                playModePauseOffsetTime = now - lastClipStart
                return time
            }
            playModePause = false
            currentTime = lastClipStart
            play()
            markSeek(to: lastClipStart)
            return lastClipStart
        }
    }

    /// Called by the timer: report the time to the delegate and apply the play mode.
    private func reportCurrentTime() {
        var time = currentTime
        if !(delegate?.isTracking ?? false) {
            time = handlePlayMode(at: time)
        }
        delegate?.timeReport(time)

        // Every second, remember the play position.
        if now - lastTimeSync > Self.syncUpdateInterval {
            lastTimeSync = now
            if time != lastCurrentPlayTimeSync {
                saveTimeToPrefs(time)
            }
        }
    }

    // MARK: Music player notifications

    @objc private func nowPlayingItemChanged() {
        musicPlayer.repeatMode = .none
    }

    @objc private func playbackStateChanged() {
        if playRequested && musicPlayer.playbackState != .playing {
            seekIssuedDuringPlay = false
        }
    }
}

extension SongList: PlaybackControllerDelegate {
    func playbackController(_ controller: PlaybackController, seekCompletedAt time: TimeInterval) {}

    func playbackControllerDidReachEnd(_ controller: PlaybackController) {
        seekIssuedDuringPlay = false
        switch playMode {
        case .repeat:
            currentTime = lastClipStart
            markSeek(to: lastClipStart)
            play()
        case .continue:
            currentTime = 0
            markSeek(to: 0)
            play()
        default:
            break
        }
    }
}
