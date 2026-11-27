//
//  AppDelegate.swift
//  SongClips
//
//  Copyright (C) 2009 John Henry Thompson.
//  2009-08-31 jht Created. Derived from AddMusic example.
//

import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    static var shared: AppDelegate {
        UIApplication.shared.delegate as! AppDelegate
    }

    /// The player screen, created once and reused.
    private(set) var mainViewController: ClipPlayCtl?
    private(set) var songListViewCtl: SongListCtl?
    var firstStopViewCtl: FirstStopViewCtl?

    /// Clips address from a `songclips:` link, waiting to be imported.
    var pendingAccessUrlStr: String?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        SongList.shared.resumeFromDisk()
        return true
    }

    /// The player screen, ready to show.
    func fetchClipPlayView() -> ClipPlayCtl {
        let controller = mainViewController ?? ClipPlayCtl(nibName: UIDevice.isPad ? "ClipPlayCtl-iPad" : "ClipPlayCtl", bundle: nil)
        mainViewController = controller
        controller.checkSongMissingMediaPending = true
        return controller
    }

    /// A new song list screen. A fresh one each time, so the same instance is never pushed twice.
    func fetchSongListView() -> SongListCtl {
        let controller = SongListCtl()
        songListViewCtl = controller
        return controller
    }

    /// Remember a `songclips:` link; the player screen imports it when it appears.
    func handleOpenURL(_ url: URL) {
        var urlString = url.absoluteString
        if let prefix = AppConfig.urlSchemePrefixes.first(where: { urlString.hasPrefix($0) }) {
            urlString.removeFirst(prefix.count)
        }
        appLog.info("open url \(urlString, privacy: .public)")
        pendingAccessUrlStr = urlString
    }
}
