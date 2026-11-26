//
//  InfoViewCtl.swift
//  SongClips
//
//  Details for the current song, plus copy, email and website actions.
//

import MediaPlayer
import MessageUI
import UIKit

final class InfoViewCtl: UITableViewController {
    private enum Row {
        case songTitle, album, artist, source, localFile
        case copy, email
        case website
    }

    private let sections: [[Row]] = [
        [.songTitle, .album, .artist, .source, .localFile],
        [.copy, .email],
        [.website],
    ]

    private let songList = SongList.shared

    init() {
        super.init(style: .grouped)
    }

    required init?(coder: NSCoder) {
        fatalError("InfoViewCtl is created in code")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = 44
        tableView.allowsSelectionDuringEditing = true

        let backButton = UIButton(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        backButton.setBackgroundImage(UIImage(named: "back_arrow.png"), for: .normal)
        backButton.addTarget(self, action: #selector(actionBack), for: .touchUpInside)
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backButton)

        title = "Info"
    }

    @objc private func actionBack() {
        navigationController?.popViewController(animated: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    // MARK: Actions

    /// Download the current song's media again from its source.
    private func downloadForCurrentSong() {
        guard let song = songList.currentSong else { return }
        song.sourceStream = false
        AppDelegate.shared.fetchClipPlayView().downloadMedia(for: song)
    }

    /// Put the current song's clips on the pasteboard as text.
    private func copyAction() {
        guard let song = songList.currentSong else { return }
        UIPasteboard.general.string = song.exportString()
        Alerts.show("Copied \(song.clipCount) clips for \(song.title ?? "")", title: "Copy")
    }

    private func emailAction() {
        guard let song = songList.currentSong else { return }
        guard MFMailComposeViewController.canSendMail() else {
            Alerts.show("Set up a mail account to email clips.", title: "Email")
            return
        }
        let mail = MFMailComposeViewController()
        mail.mailComposeDelegate = self
        mail.setMessageBody(song.exportString(), isHTML: false)
        mail.setSubject("\(AppInfo.name) for \(song.label ?? "") (\(song.clipCount) clips)")
        present(mail, animated: true)
    }

    /// Let the user pick different media for the current song.
    private func selectReplacementForCurrentSong() {
        if songList.isVideo {
            let browser = VideoBrowserController(title: "Select Replacement Video") { [weak self] item in
                self?.navigationController?.popViewController(animated: true)
                self?.replaceCurrentSongMedia(item)
            }
            navigationController?.pushViewController(browser, animated: true)
        } else {
            let picker = MPMediaPickerController(mediaTypes: .any)
            picker.delegate = self
            picker.allowsPickingMultipleItems = false
            picker.prompt = "Select Replacement"
            present(picker, animated: true)
        }
    }

    private func replaceCurrentSongMedia(_ item: MPMediaItem) {
        guard let song = songList.currentSong else { return }
        song.applyReplacement(item)
        song.saveToDisk()
        songList.selectSong(song)
        tableView.reloadData()
    }

    // MARK: Table view

    override func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].count
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 0 ? 26 : 8
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 2 }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "Clips For: \(songList.currentSong?.label ?? "")" : nil
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch sections[indexPath.section][indexPath.row] {
        case .songTitle: selectReplacementForCurrentSong()
        case .source: downloadForCurrentSong()
        case .copy: copyAction()
        case .email: emailAction()
        case .website: openInBrowser(AppConfig.webSite)
        case .album, .artist, .localFile: break
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section][indexPath.row]
        let song = songList.currentSong
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        var content = cell.defaultContentConfiguration()
        cell.accessoryType = .none

        switch row {
        case .songTitle:
            if let song {
                content.text = song.title
                content.secondaryText = songList.isVideo ? "Title (video)" : "Title (music)"
                content.textProperties.color = .songClipsGreen
            } else {
                content.text = "No Media"
            }
            cell.accessoryType = .disclosureIndicator
        case .album:
            content.text = song?.albumTitle
            content.secondaryText = song == nil ? nil : "Album"
        case .artist:
            content.text = song?.artist
            content.secondaryText = song == nil ? nil : "Artist"
        case .source:
            content.text = song?.sourceForLocal
            content.secondaryText = song?.sourceStream == true ? "Stream" : nil
            cell.accessoryType = .disclosureIndicator
        case .localFile:
            content.text = song?.partialPath
            content.secondaryText = song?.fileDisplaySize
        case .copy:
            content.text = "Copy"
            cell.accessoryType = .disclosureIndicator
        case .email:
            content.text = "Email"
            cell.accessoryType = .disclosureIndicator
        case .website:
            content.text = "SongClips Website"
            cell.accessoryType = .disclosureIndicator
        }
        cell.contentConfiguration = content
        return cell
    }
}

extension InfoViewCtl: MFMailComposeViewControllerDelegate {
    func mailComposeController(
        _ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?
    ) {
        if result == .failed {
            appLog.error("Email failed: \(error?.localizedDescription ?? "", privacy: .public)")
        }
        controller.dismiss(animated: true)
    }
}

extension InfoViewCtl: MPMediaPickerControllerDelegate {
    func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
        mediaPicker.dismiss(animated: true)
        if let item = mediaItemCollection.items.first {
            replaceCurrentSongMedia(item)
        }
    }

    func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
        mediaPicker.dismiss(animated: true)
    }
}
