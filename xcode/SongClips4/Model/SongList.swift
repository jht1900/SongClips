//
//  SongList.swift
//  SongClips4
//
//  Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
//
//  The user's songs, and playback of the current song with clip-aware play modes.
//  Music library songs play with MPMusicPlayerController; video, local files and
//  streams play with AVPlayer. Songs with no media play on a simulated clock.
//
//  SwiftUI views observe `reportedTime`, `reportedClipIndex` and `playing`,
//  which a timer updates ten times a second while the app is active.
//

import MediaPlayer
import Observation
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

@Observable
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

    // MARK: Observed state

    /// The play position, updated by the timer and by seeks.
    private(set) var reportedTime: TimeInterval = 0
    /// Index of the clip at `reportedTime`.
    private(set) var reportedClipIndex = 0
    /// Whether the current song is playing, updated by the timer.
    private(set) var playing = false
    /// True when the current song plays with AVPlayer, so video is shown.
    private(set) var useAVPlayer = false
    private(set) var songs: [Song] = []
    private(set) var currentSongIndex = 0
    private(set) var playMode: ClipPlayMode = .none

    // MARK: Players

    /// Shows video for AVPlayer playback. One view, reused by every player screen.
    @ObservationIgnored let playbackView = PlaybackView()
    @ObservationIgnored private(set) var avPlayerCtl: PlaybackController?
    @ObservationIgnored let musicPlayer: MPMusicPlayerController
    @ObservationIgnored let imageCache = ImageCache(allowance: AppConfig.maxCacheImages)
    @ObservationIgnored let imageIconCache = ImageCache(allowance: AppConfig.maxCacheImageIcons)

    /// True while the user drags the scrubber; play-mode handling waits until they let go.
    @ObservationIgnored var isTracking = false
    @ObservationIgnored var dirty = false

    @ObservationIgnored private var nextSongID = 0
    @ObservationIgnored private var updateTimer: Timer?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    /// Set when the clip must be established on the next report even if its index is unchanged.
    @ObservationIgnored private var forceClipReport = true

    @ObservationIgnored private var clipStartTime: TimeInterval = 0
    @ObservationIgnored private var lastTimeSync: TimeInterval = 0
    @ObservationIgnored private var lastCurrentPlayTimeSync: TimeInterval = 0

    // Songs with no media play on a simulated clock.
    @ObservationIgnored private var missingMediaItem = false
    @ObservationIgnored private var missingMediaIsPlaying = false
    @ObservationIgnored private var missingMediaOffsetTime: TimeInterval = 0
    @ObservationIgnored private var missingMediaCurrentTime: TimeInterval = 0

    @ObservationIgnored private var lastClipIndex = 0
    @ObservationIgnored private var lastClipStart: TimeInterval = 0
    @ObservationIgnored private var lastClipDuration: TimeInterval = 0

    /// Paused at the end of a clip by a pause play mode.
    @ObservationIgnored private var playModePause = false
    @ObservationIgnored private var playModePauseOffsetTime: TimeInterval = 0

    /// After a seek the player can briefly report a time just before the target;
    /// while this is set, report the target instead so the clip display does not flicker.
    @ObservationIgnored private var seekIssuedDuringPlay = false
    @ObservationIgnored private var seekIssuedDuringPlayTime: TimeInterval = 0

    @ObservationIgnored private var userDefaultsSyncNeeded = false
    @ObservationIgnored private var playRequested = false

    @ObservationIgnored private var speedShiftEnabled = false
    @ObservationIgnored private var speedShiftStartTime: TimeInterval = 0
    @ObservationIgnored private var speedShiftIndex = 0

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
        observers.append(
            nc.addObserver(forName: .MPMusicPlayerControllerNowPlayingItemDidChange, object: musicPlayer, queue: .main) {
                [weak self] _ in
                MainActor.assumeIsolated { self?.musicPlayer.repeatMode = .none }
            })
        observers.append(
            nc.addObserver(forName: .MPMusicPlayerControllerPlaybackStateDidChange, object: musicPlayer, queue: .main) {
                [weak self] _ in
                MainActor.assumeIsolated { self?.playbackStateChanged() }
            })
        musicPlayer.beginGeneratingPlaybackNotifications()
    }

    func reportSongChange() {
        forceClipReport = true
        reportedTime = currentTime
    }

    // MARK: App lifecycle

    /// The app is leaving the foreground: save state and stop the timer.
    func willResignActive() {
        // clipStartTime is reported while the music player is inactive.
        clipStartTime = lastCurrentPlayTimeSync
        checkPrefSync()
        if dirty { saveToDisk() }
        updateTimer?.invalidate()
        updateTimer = nil
    }

    /// The app is in the foreground: restore the song and position, and start the timer.
    func becomeActive() {
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
        reportSongChange()
    }

    // MARK: Choosing the song

    private func setupSong(at index: Int) {
        if index >= songCount {
            musicPlayer.stop()
        } else {
            let song = song(at: index)
            missingMediaItem = song.mediaItem == nil && !(song.sourceForLocal != nil && song.url != nil)
            if missingMediaItem {
                useAVPlayer = false
                replacePlaybackController(nil)
                musicPlayer.stop()
            } else if let url = song.url {
                useAVPlayer = true
                let oldTime = avPlayerCtl?.currentTime ?? 0
                let controller = PlaybackController()
                replacePlaybackController(controller)
                controller.delegate = self
                controller.attach(to: playbackView)
                controller.load(url)
                controller.currentTime = oldTime
            } else if let item = song.mediaItem {
                useAVPlayer = false
                replacePlaybackController(nil)
                if musicPlayer.nowPlayingItem != item {
                    musicPlayer.setQueue(with: MPMediaItemCollection(items: [item]))
                }
            }
        }
        currentSongIndex = index
        reportSongChange()
    }

    private func replacePlaybackController(_ controller: PlaybackController?) {
        if controller !== avPlayerCtl { avPlayerCtl?.invalidate() }
        avPlayerCtl = controller
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

    /// Look up every song's media again, e.g. after the user allows Music library access.
    func refreshMediaItems() {
        for song in songs where song.title != nil {
            song.queryForMediaItem()
        }
        setupSong(at: currentSongIndex)
    }

    /// Point the current song at different Music library media.
    func replaceCurrentSongMedia(_ item: MPMediaItem) {
        guard let song = currentSong else { return }
        song.applyReplacement(item)
        song.saveToDisk()
        selectSong(song)
    }

    // MARK: Song storage

    var songCount: Int { songs.count }

    func song(at index: Int) -> Song {
        songs[index]
    }

    func moveSongs(fromOffsets source: IndexSet, toOffset destination: Int) {
        let current = currentSong
        songs.move(fromOffsets: source, toOffset: destination)
        if let current, let index = songs.firstIndex(where: { $0 === current }) {
            currentSongIndex = index
            rememberCurrentSongIndex()
        }
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
            songs = (dict[Key.songFileNames] as? [String] ?? []).map { name in
                let song = Song()
                song.storeName = name
                song.restoreFromDisk()
                return song
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
            updatePlaying(true)
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
        updatePlaying(true)
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
        updatePlaying(false)
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }

    private func updatePlaying(_ value: Bool) {
        if playing != value { playing = value }
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
            return time.isFinite ? time : 0
        }
        set {
            setCurrentTimeOnPlayer(newValue)
            saveTimeToPrefs(newValue)
            if playRequested { markSeek(to: newValue) }
            establishClip(at: currentSong?.clipIndex(for: newValue) ?? 0)
            report(newValue)
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
    private func speedShiftMonitor(_ song: Song) {
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

    private func applyPlayMode(_ mode: ClipPlayMode) {
        playMode = mode
        playModePause = false
        establishClip(at: currentClipIndex)
        _ = handlePlayMode(at: currentTime)
    }

    /// Change the play mode. It is remembered across launches.
    func setPlayMode(_ mode: ClipPlayMode) {
        applyPlayMode(mode)
        UserDefaults.standard.set(mode.rawValue, forKey: DefaultsKey.songPlayMode)
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
        currentTime = next.startTime
        if playNeeded { play() }
        // In pause mode the next clip sometimes gets stuck without this.
        markSeek(to: next.startTime)
    }

    func previousClip() {
        if !playModePause && currentTime > lastClipStart + Self.previousClipRestartWindow {
            setCurrentTimeOnPlayer(lastClipStart)
            report(lastClipStart)
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
        currentTime = song.clip(at: index)?.startTime ?? 0
        if playNeeded { play() }
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

    /// Publish `time`; when it moves into a different clip, make that clip current.
    private func report(_ time: TimeInterval) {
        reportedTime = time
        let index = currentSong?.clipIndex(for: time) ?? 0
        if index != reportedClipIndex || forceClipReport {
            forceClipReport = false
            establishClip(at: index)
            if index != reportedClipIndex { reportedClipIndex = index }
        }
    }

    /// Called by the timer: publish the time and apply the play mode.
    private func reportCurrentTime() {
        var time = currentTime
        if !isTracking {
            time = handlePlayMode(at: time)
        }
        report(time)
        updatePlaying(isPlaying)
        if let song = currentSong { speedShiftMonitor(song) }

        // Every second, remember the play position.
        if now - lastTimeSync > Self.syncUpdateInterval {
            lastTimeSync = now
            if time != lastCurrentPlayTimeSync {
                saveTimeToPrefs(time)
            }
        }
    }

    // MARK: Music player notifications

    private func playbackStateChanged() {
        if playRequested && musicPlayer.playbackState != .playing {
            seekIssuedDuringPlay = false
        }
        updatePlaying(isPlaying)
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
