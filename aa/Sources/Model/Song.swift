//
//  Song.swift
//  SongClips
//
//  Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
//
//  A song (from the Music library, a local file, or a stream) divided into clips.
//

import MediaPlayer
import UIKit

final class Song {
    /// Keys in song.plist. These must not change: existing user data depends on them.
    private enum Key {
        static let persistentID = "persistentID"
        static let albumTitle = "albumTitle"
        static let title = "title"
        static let artist = "artist"
        static let duration = "duration"
        static let currentPos = "position"
        static let label = "label"
        static let nextRecordingID = "nextRecordingID"
        static let sourceRef = "sourceRef"
        static let clipsSourceRef = "clipsSourceRef"
        static let clipList = "cliplist"
        static let sourceForLocal = "K_sourceForLocal"
        static let partialPath = "K_partialPath"
        static let isVideo = "K_s_mediaItem_video"
        static let sourceStream = "K_source_stream"
        static let speedShiftList = "K_speed_shift_list"
    }

    var mediaItem: MPMediaItem?
    /// Playable URL for video, local files and streams. Played with AVPlayer.
    var url: URL?
    var persistentID: NSNumber?
    /// Web address the song's media is downloaded or streamed from.
    var sourceForLocal: String?
    /// Path of the downloaded media file, relative to `Storage.rootPath`.
    var partialPath: String?
    var albumTitle: String?
    var title: String?
    var artist: String?
    var label: String?
    /// Folder name for this song under `Storage.rootURL`.
    var storeName: String?
    /// Web page where the user can find the song's media.
    var sourceRef: String?
    /// Web address to import this song's clips from.
    var clipsSourceRef: String?
    var clips: [Clip] = []
    /// Timed playback-rate changes: [["duration": seconds, "rate": rate], ...].
    var speedShiftList: [[String: Any]]?

    var duration: TimeInterval = 0
    var currentPos: TimeInterval = 0
    var nextRecordingID = 0

    var mediaMissing = false
    var mediaMissingShown = false
    var isVideo = false
    /// Imported from JSON; media still has to be downloaded or streamed.
    var initDeferred = false
    var pauseOnLoad = false
    var sourceStream = false

    private var cachedImageIcon: UIImage?

    init() {}

    // MARK: Creating songs

    /// A new song for a Music library item, with one clip covering the whole song.
    static func make(mediaItem: MPMediaItem) -> Song {
        let song = Song()
        song.applyReplacement(mediaItem)
        song.label = song.title
        song.nextRecordingID = 0
        song.resetClipList()
        song.freshSave()
        return song
    }

    /// Fill this song from a text export or a JSON description, then save it.
    func load(fromExport string: String) {
        if string.hasPrefix("{") {
            parseJSON(string)
        } else {
            parseExportString(string)
            findMediaItem()
        }
        freshSave()
    }

    /// Finish setting up a song whose media was downloaded or is streamed.
    func initForLocal() {
        if title == nil { title = partialPath.map { ($0 as NSString).lastPathComponent } }
        albumTitle = title
        label = title
        if clips.isEmpty { resetClipList() }
        freshSave()
    }

    func newClip() -> Clip {
        Clip(song: self)
    }

    /// Replace the clips with a single clip covering the whole song.
    private func resetClipList() {
        let clip = newClip()
        clip.notation = title
        clip.subDuration = duration
        clip.startTime = 0
        clip.recordingDuration = 0
        clips = [clip]
    }

    /// Point this song at a different Music library item.
    func applyReplacement(_ item: MPMediaItem) {
        mediaItem = item
        persistentID = NSNumber(value: item.persistentID)
        albumTitle = item.albumTitle
        title = item.title
        artist = item.artist
        duration = item.playbackDuration
        isVideo = !item.mediaType.intersection(.anyVideo).isEmpty
        if isVideo {
            url = item.assetURL
        }
        mediaMissing = false
        appLog.debug("Song applyReplacement title=\(self.title ?? "", privacy: .public) isVideo=\(self.isVideo)")
    }

    private func parseJSON(_ string: String) {
        let dict: [String: Any]
        do {
            guard let parsed = try JSONSerialization.jsonObject(with: Data(string.utf8)) as? [String: Any] else {
                return
            }
            dict = parsed
        } catch {
            Alerts.showError("Could not read SongClips JSON: \(error.localizedDescription)")
            return
        }
        initDeferred = true
        title = dict["title"] as? String
        duration = (dict["duration"] as? NSNumber)?.doubleValue ?? 0
        sourceForLocal = dict["source_url"] as? String
        pauseOnLoad = (dict["pause_on_load"] as? NSNumber)?.boolValue ?? false
        sourceStream = (dict["source_stream"] as? NSNumber)?.boolValue ?? false
        speedShiftList = dict["speed_shift_list"] as? [[String: Any]]

        if let sourceClips = dict["clip_list"] as? [[String: Any]] {
            var start: TimeInterval = 0
            clips = sourceClips.map { source in
                let clip = newClip()
                clip.notation = source["title"] as? String
                clip.subDuration = (source["duration"] as? NSNumber)?.doubleValue ?? 0
                clip.clipRate = (source["rate"] as? NSNumber)?.doubleValue ?? 0
                clip.startTime = start
                start += clip.subDuration
                return clip
            }
        }
    }

    // MARK: Saving

    /// Folder name for this song, assigned on first use.
    var ensuredStoreName: String {
        if let storeName { return storeName }
        let name = SongList.shared.nextSongFileName(prefix: label ?? title)
        storeName = name
        return name
    }

    /// Assign a folder name and save both the song and the song list.
    private func freshSave() {
        _ = ensuredStoreName
        saveToDisk()
        // The song list must save so its array of folder names is up to date.
        SongList.shared.saveToDisk()
    }

    var directoryURL: URL {
        Storage.rootURL.appendingPathComponent(ensuredStoreName, isDirectory: true)
    }

    func pathForMediaFile(_ fileName: String) -> String {
        directoryURL.appendingPathComponent(fileName).path
    }

    /// Return the next file name for a clip's media file, e.g. "3-image.png".
    func nextMediaFileName(suffix: String) -> String {
        defer { nextRecordingID += 1 }
        return "\(nextRecordingID)-\(suffix)"
    }

    private var asDict: [String: Any] {
        var dict: [String: Any] = [
            Key.clipList: clips.map(\.asDict),
            Key.nextRecordingID: nextRecordingID,
            Key.duration: duration,
            Key.currentPos: currentPos,
            Key.isVideo: isVideo,
            Key.sourceStream: sourceStream,
        ]
        dict[Key.persistentID] = persistentID
        dict[Key.albumTitle] = albumTitle
        dict[Key.title] = title
        dict[Key.artist] = artist
        dict[Key.label] = label
        dict[Key.sourceRef] = sourceRef
        dict[Key.clipsSourceRef] = clipsSourceRef
        dict[Key.sourceForLocal] = sourceForLocal
        dict[Key.partialPath] = partialPath
        dict[Key.speedShiftList] = speedShiftList
        return dict
    }

    func saveToDisk() {
        appLog.debug("Song saveToDisk clips=\(self.clips.count)")
        let dir = directoryURL
        Storage.createDirectory(dir)
        Storage.writePlist(asDict, to: dir.appendingPathComponent(StoreFile.songPlist))
    }

    /// Read the song from `<root>/<storeName>/song.plist`.
    func restoreFromDisk() {
        let url = directoryURL.appendingPathComponent(StoreFile.songPlist)
        guard let dict = Storage.readPlist(at: url) else {
            appLog.error("Song restoreFromDisk failed for \(self.storeName ?? "nil", privacy: .public)")
            return
        }
        load(from: dict)
    }

    private func load(from dict: [String: Any]) {
        persistentID = dict[Key.persistentID] as? NSNumber
        albumTitle = dict[Key.albumTitle] as? String
        title = dict[Key.title] as? String
        artist = dict[Key.artist] as? String
        duration = (dict[Key.duration] as? NSNumber)?.doubleValue ?? 0
        currentPos = (dict[Key.currentPos] as? NSNumber)?.doubleValue ?? 0
        label = dict[Key.label] as? String ?? title
        nextRecordingID = (dict[Key.nextRecordingID] as? NSNumber)?.intValue ?? 0
        sourceRef = dict[Key.sourceRef] as? String
        clipsSourceRef = dict[Key.clipsSourceRef] as? String
        sourceForLocal = dict[Key.sourceForLocal] as? String
        partialPath = dict[Key.partialPath] as? String
        isVideo = (dict[Key.isVideo] as? NSNumber)?.boolValue ?? false
        sourceStream = (dict[Key.sourceStream] as? NSNumber)?.boolValue ?? false
        speedShiftList = dict[Key.speedShiftList] as? [[String: Any]]

        queryForMediaItem()

        var start: TimeInterval = 0
        clips = (dict[Key.clipList] as? [[String: Any]] ?? []).map { clipDict in
            let clip = newClip()
            clip.load(from: clipDict)
            clip.startTime = start
            start += clip.subDuration
            return clip
        }
    }

    // MARK: Finding media

    /// Find the media for this song: a URL for local or streamed media,
    /// otherwise the Music library item by persistent ID, then by title.
    func queryForMediaItem() {
        if let sourceForLocal {
            if sourceStream {
                url = URL(string: sourceForLocal)
            } else if let partialPath {
                url = URL(fileURLWithPath: Storage.rootPath + partialPath)
            }
            if url == nil { mediaMissing = true }
            return
        }
        guard let persistentID else {
            findMediaItem()
            return
        }
        let query = MPMediaQuery()
        query.addFilterPredicate(
            MPMediaPropertyPredicate(value: persistentID, forProperty: MPMediaItemPropertyPersistentID))
        if let item = query.items?.first {
            mediaItem = item
            if isVideo { url = item.assetURL }
            mediaMissing = false
        } else {
            mediaItem = nil
            mediaMissing = true
            findMediaItem()
        }
    }

    /// Look for the song in the Music library by title, album and artist, then by title alone.
    private func findMediaItem() {
        findMediaItem(titleOnly: false)
        if mediaMissing { findMediaItem(titleOnly: true) }
    }

    private func findMediaItem(titleOnly: Bool) {
        guard let title else { return }
        let query = MPMediaQuery()
        query.addFilterPredicate(MPMediaPropertyPredicate(value: title, forProperty: MPMediaItemPropertyTitle))
        if isVideo {
            query.addFilterPredicate(
                MPMediaPropertyPredicate(
                    value: NSNumber(value: MPMediaType.anyVideo.rawValue), forProperty: MPMediaItemPropertyMediaType))
        }
        if !titleOnly {
            if let albumTitle {
                query.addFilterPredicate(
                    MPMediaPropertyPredicate(value: albumTitle, forProperty: MPMediaItemPropertyAlbumTitle))
            }
            if let artist {
                query.addFilterPredicate(MPMediaPropertyPredicate(value: artist, forProperty: MPMediaItemPropertyArtist))
            }
        }
        if let item = query.items?.first {
            mediaItem = item
            persistentID = NSNumber(value: item.persistentID)
            mediaMissing = false
            if isVideo { url = item.assetURL }
        } else {
            mediaItem = nil
            mediaMissing = true
            appLog.debug("Song findMediaItem: not found title=\(title, privacy: .public)")
        }
    }

    // MARK: Clips

    var clipCount: Int { clips.count }

    func clip(at index: Int) -> Clip? {
        clips.indices.contains(index) ? clips[index] : nil
    }

    /// Index of the clip playing at `time`.
    func clipIndex(for time: TimeInterval) -> Int {
        let index = clips.firstIndex { $0.startTime > time } ?? clips.count
        return max(index - 1, 0)
    }

    /// Split the clip at `index`: it keeps `newSubDuration`, and a new clip after it gets the rest.
    func splitClip(at index: Int, newSubDuration: TimeInterval) {
        guard let clip = clip(at: index) else { return }
        let remainder = clip.subDuration - newSubDuration
        guard remainder >= 0 else { return }
        clip.subDuration = newSubDuration
        let next = newClip()
        next.subDuration = remainder
        next.startTime = clip.startTime + newSubDuration
        clips.insert(next, at: index + 1)
        saveToDisk()
    }

    /// Remove the clip at `index`, giving its time to the clip before it (or after it, for the first clip).
    func removeClip(at index: Int) {
        guard clipCount > 1, let clip = clip(at: index) else { return }
        clips.remove(at: index)
        let neighborIndex = max(index - 1, 0)
        let neighbor = clips[neighborIndex]
        if neighborIndex == index {
            neighbor.startTime = 0
        }
        if (neighbor.notation ?? "").isEmpty, let notation = clip.notation {
            neighbor.notation = notation
        }
        neighbor.subDuration += clip.subDuration
        clip.removeMediaFiles()
        saveToDisk()
    }

    func removeAllClips() {
        resetClipList()
        saveToDisk()
    }

    /// Replace the clips with `count` equal clips.
    func makeClips(_ count: Int) {
        let length = duration / Double(count)
        clips = (0..<count).map { index in
            let clip = newClip()
            clip.subDuration = length
            clip.startTime = Double(index) * length
            return clip
        }
        saveToDisk()
    }

    func saveNewImage(_ image: UIImage, forClipAt index: Int) {
        clip(at: index)?.saveNewImage(image)
    }

    // MARK: Display

    var imageIcon: UIImage? {
        if cachedImageIcon == nil {
            cachedImageIcon = mediaItem?.artwork?.image(at: CGSize(width: 32, height: 32))
        }
        return cachedImageIcon
    }

    /// Size of the downloaded media file, e.g. "12.3 MB".
    var fileDisplaySize: String {
        guard let partialPath,
            let attributes = try? FileManager.default.attributesOfItem(atPath: Storage.rootPath + partialPath),
            let size = attributes[.size] as? NSNumber
        else { return "" }
        return Format.bytes(size.doubleValue)
    }

    // MARK: Text export

    /// The song and its clips in the SongClips text export format.
    func exportString() -> String {
        var out = "\nSong Label: \(label ?? "(null)")\n"
        out += "Song Title: \(title ?? "(null)")\n"
        if let albumTitle { out += "Album Title: \(albumTitle)\n" }
        if let artist { out += "Artist: \(artist)\n" }
        out += "Duration: \(Format.exportDuration(duration))\n"
        out += "Clips: \(clipCount)\n"
        out += "Exporter: \(AppInfo.nameVersion)\nExport Date: \(Date().description)\n"
        if let sourceRef, !sourceRef.isEmpty { out += "Source: \(sourceRef)\n" }
        if isVideo { out += "Video: 1\n" }
        for (index, clip) in clips.enumerated() {
            out += "Clip: \(index + 1)\nStartTime: \(Format.exportDuration(clip.startTime))\n"
            out += "Duration: \(Format.exportDuration(clip.subDuration))\n"
            if let imageRef = clip.imageRef { out += "Image: \(imageRef)\n" }
            if let linkRef = clip.linkRef { out += "Link: \(linkRef)\n" }
            if let webRef = clip.webRef { out += "Web: \(webRef)\n" }
            for text in clip.texts ?? [] {
                // Multi-line text goes in a Text[ ... ]Text block.
                out += text.contains("\n") ? "Text[\n\(text)\n]Text\n" : "Text: \(text)\n"
            }
        }
        return out
    }

    private func parseExportString(_ string: String) {
        let scanner = ExportScanner(string: string)
        clips = []
        label = ""
        title = ""
        while !scanner.isAtEnd {
            guard scanner.nextLine(), let line = scanner.line else { continue }
            if let value = scanner.value(after: "Song Label:") {
                label = value
            } else if let value = scanner.value(after: "Song Title:") {
                title = value
            } else if let value = scanner.value(after: "Album Title:") {
                albumTitle = value
            } else if let value = scanner.value(after: "Artist:") {
                artist = value
            } else if let value = scanner.value(after: "Source:") {
                sourceRef = value
            } else if scanner.value(after: "Video:") != nil {
                isVideo = true
            } else if let value = scanner.duration(after: "Duration:") {
                duration = value
            } else if scanner.value(after: "Clips:") != nil
                || scanner.value(after: "Exporter:") != nil
                || scanner.value(after: "Export Date:") != nil
            {
                // Informational only.
            } else if scanner.value(after: "Clip:") != nil {
                while parseClip(scanner) {}
            } else if !line.isEmpty {
                appLog.debug("Song import skipping line: \(line, privacy: .public)")
            }
        }
    }

    /// Parse one clip. Returns true when another clip follows.
    private func parseClip(_ scanner: ExportScanner) -> Bool {
        let clip = newClip()
        var texts: [String] = []
        var more = false
        while !scanner.isAtEnd {
            guard scanner.nextLine(), let line = scanner.line else { continue }
            if let value = scanner.duration(after: "StartTime:") {
                clip.startTime = value
            } else if let value = scanner.duration(after: "Duration:") {
                clip.subDuration = value
            } else if let value = scanner.value(after: "Link:") {
                clip.linkRef = value
            } else if let value = scanner.value(after: "Image:") {
                clip.imageRef = value
            } else if let value = scanner.value(after: "Web:") {
                clip.webRef = value
            } else if scanner.value(after: "Clip:") != nil {
                more = true
                break
            } else if scanner.value(after: "Song End:") != nil {
                break
            } else if let text = scanner.textBlock(tag: "Text") {
                texts.append(text)
            } else {
                // Keep unrecognized lines as notes.
                texts.append(line)
            }
        }
        clip.texts = texts
        clips.append(clip)
        return more
    }
}

enum AppInfo {
    static var name: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "SongClips"
    }

    /// e.g. "SongClips 1".
    static var nameVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return "\(name) \(version)"
    }
}
