//
//  FirstStopViewCtl.swift
//  SongClips
//
//  2011-11-21 jht
//
//  Root of the navigation stack. Shows the launch image and moves on to the song list.
//

import UIKit

final class FirstStopViewCtl: UIViewController {
    override func loadView() {
        let imageView = UIImageView(image: UIImage(named: "Default.png"))
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .white
        view = imageView
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let navigationController, navigationController.topViewController === self else { return }
        navigationController.pushViewController(AppDelegate.shared.fetchSongListView(), animated: true)
    }

    /// When a `songclips:` link is waiting, bring the song list to the top so it can be imported.
    func becomeActive() {
        let app = AppDelegate.shared
        guard app.pendingAccessUrlStr != nil, let navigationController else { return }

        navigationController.presentedViewController?.dismiss(animated: false)

        // Popping and pushing the song list would not trigger its appearance events.
        if let songList = app.songListViewCtl, navigationController.topViewController === songList {
            songList.becomeActive()
            return
        }
        navigationController.popToRootViewController(animated: false)
        navigationController.pushViewController(app.fetchSongListView(), animated: true)
    }
}
