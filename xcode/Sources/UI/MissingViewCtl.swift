//
//  MissingViewCtl.swift
//  SongClips
//
//  2011-11-21 jht
//
//  Shown when an imported song's media is not in the Music library.
//

import UIKit

final class MissingViewCtl: UIViewController {
    @IBOutlet private var songLabel: UILabel!
    @IBOutlet private var albumLabel: UILabel!
    @IBOutlet private var artistLabel: UILabel!

    private var song: Song? { AppDelegate.shared.mainViewController?.currentSong }

    override func viewDidLoad() {
        super.viewDidLoad()
        songLabel.text = song?.title
        albumLabel.text = song?.albumTitle
        artistLabel.text = song?.artist
    }

    /// Open the song's source page so the user can get the media.
    @IBAction private func searchAction(_ sender: Any?) {
        let sourceRef = song?.sourceRef
        dismiss(animated: true)
        if let sourceRef {
            openInBrowser(sourceRef)
        }
    }

    @IBAction private func continueAction(_ sender: Any?) {
        dismiss(animated: true)
    }

    /// Pick other media for the song; the player screen shows the picker when it reappears.
    @IBAction private func selectOtherAction(_ sender: Any?) {
        dismiss(animated: true)
        AppDelegate.shared.mainViewController?.selectReplacementForCurrentSongPending = true
    }
}
