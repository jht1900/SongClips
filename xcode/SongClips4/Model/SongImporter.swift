//
//  SongImporter.swift
//  SongClips4
//
//  Imports songs from SongClips addresses (text export or JSON) and downloads
//  their media (formerly part of ClipPlayCtl).
//

import Foundation
import Observation

@Observable
final class SongImporter {
    static let shared = SongImporter()

    /// How long the download result stays in the player's title.
    private static let statusHold: Duration = .seconds(1)

    /// File being downloaded, shown in the player's title while `downloadStatus` is set.
    private(set) var downloadTitle = ""
    /// Download progress or result; nil when no download is shown.
    private(set) var downloadStatus: String?

    @ObservationIgnored private let songList = SongList.shared
    @ObservationIgnored private var accessActive = false

    /// Import from `urlString`. With `existing`, its clips are replaced instead of adding a song.
    func access(_ urlString: String, into existing: Song? = nil) {
        guard !accessActive else { return }
        accessActive = true
        Task {
            defer { accessActive = false }
            do {
                let data = try await SiteClient.fetch(urlString)
                importSongData(data, into: existing)
            } catch {
                appLog.error("Import failed \(urlString, privacy: .public): \(error.localizedDescription, privacy: .public)")
                Alerts.show(error.localizedDescription, title: "Import failed")
            }
        }
    }

    private func importSongData(_ data: Data, into existing: Song?) {
        let text = String(decoding: data, as: UTF8.self)
        let song = songList.importSong(from: text, into: existing)

        guard song.initDeferred else {
            setupNewSong(song)
            return
        }
        guard let source = song.sourceForLocal, let url = URL(string: source) else {
            appLog.error("Imported song has no source url")
            return
        }
        if song.sourceStream {
            SiteClient.prepareStreamCredential(for: url)
            song.url = url
            initNewSong(song)
        } else {
            downloadMedia(for: song, from: url)
        }
    }

    /// Download the song's media again from its `sourceForLocal` address.
    func downloadMedia(for song: Song) {
        Navigator.shared.showPlayer()
        guard let source = song.sourceForLocal, let url = URL(string: source) else { return }
        downloadMedia(for: song, from: url)
    }

    private func downloadMedia(for song: Song, from url: URL) {
        let fileName = AppConfig.songMediaFilePrefix + url.lastPathComponent
        // Stored relative to the storage root as "/<song folder>/media-<name>".
        let partialPath = "/" + song.ensuredStoreName + "/" + fileName
        let destination = URL(fileURLWithPath: Storage.rootPath + partialPath)
        song.url = destination
        song.partialPath = partialPath
        downloadTitle = fileName
        downloadStatus = "Downloading"

        let downloader = FileDownloader(
            destination: destination,
            progress: { [weak self] bytes in
                self?.downloadStatus = "Downloading \(Format.bytes(Double(bytes)))"
            },
            completion: { [weak self] error in
                self?.downloadFinished(error: error)
                self?.initNewSong(song)
            })
        downloader.start(from: url)
    }

    private func downloadFinished(error: Error?) {
        downloadStatus = error == nil ? "Download done" : "Download failed"
        Task {
            try? await Task.sleep(for: Self.statusHold)
            downloadStatus = nil
        }
    }

    private func initNewSong(_ song: Song) {
        song.initDeferred = false
        song.initForLocal()
        setupNewSong(song)
    }

    /// Make the imported song current, from its beginning, in the player.
    private func setupNewSong(_ song: Song) {
        songList.selectSong(song)
        songList.currentTime = 0
        Navigator.shared.showPlayer()
    }
}
