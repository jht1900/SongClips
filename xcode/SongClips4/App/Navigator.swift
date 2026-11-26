//
//  Navigator.swift
//  SongClips4
//
//  The navigation stack and the requests that cross screens
//  (formerly spread across AppDelegate, FirstStopViewCtl and SongListCtl).
//

import Foundation
import Observation

/// Screens pushed on top of the song list.
enum Route: Hashable {
    case player
    case clips
    case info
    case web(URL)
    case videoBrowser(VideoBrowserPurpose)
}

enum VideoBrowserPurpose: Hashable {
    case addSong
    case replaceCurrentSong
}

@Observable
final class Navigator {
    static let shared = Navigator()

    var path: [Route] = []

    /// When the player next appears, explain if the song's media is missing.
    var checkMissingMediaPending = false
    /// Playback has auto-started once since launch.
    var autoPlayDone = false

    /// Show the player, popping anything above it.
    func showPlayer() {
        checkMissingMediaPending = true
        if let index = path.firstIndex(of: .player) {
            path.removeSubrange((index + 1)...)
        } else {
            path = [.player]
        }
    }

    func push(_ route: Route) {
        path.append(route)
    }

    func pop() {
        if !path.isEmpty { path.removeLast() }
    }

    /// Import the song named by a `songclips:` link and show it in the player.
    func handleOpenURL(_ url: URL) {
        var urlString = url.absoluteString
        if let prefix = AppConfig.urlSchemePrefixes.first(where: { urlString.hasPrefix($0) }) {
            urlString.removeFirst(prefix.count)
        }
        appLog.info("open url \(urlString, privacy: .public)")
        showPlayer()
        SongImporter.shared.access(urlString)
    }
}
