//
//  SongListCtl.swift
//  SongClips
//
//  Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
//
//  The list of songs, with a last row for adding more.
//

import MediaPlayer
import UIKit

final class SongListCtl: UITableViewController {
    private let songList = SongList.shared
    private var selectIndexPath: IndexPath?

    init() {
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) {
        fatalError("SongListCtl is created in code")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = 54
        tableView.allowsSelectionDuringEditing = true

        let iconButton = UIButton(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        iconButton.setBackgroundImage(UIImage(named: "icon_48.png"), for: .normal)
        iconButton.addTarget(self, action: #selector(actionOptions), for: .touchUpInside)
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: iconButton)
        navigationItem.rightBarButtonItem = editButtonItem

        title = AppInfo.nameVersion
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()

        if let selectIndexPath {
            tableView.deselectRow(at: selectIndexPath, animated: true)
        }
        if songList.currentSong != nil {
            let indexPath = IndexPath(row: songList.currentSongIndex, section: 0)
            tableView.selectRow(at: indexPath, animated: animated, scrollPosition: .middle)
            selectIndexPath = indexPath
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeActive()
    }

    /// Show the player when a `songclips:` link is waiting to be imported.
    func becomeActive() {
        guard AppDelegate.shared.pendingAccessUrlStr != nil else { return }
        navigationController?.pushViewController(AppDelegate.shared.fetchClipPlayView(), animated: true)
    }

    // MARK: Menus

    @objc private func actionOptions() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "SongClips Website", style: .default) { _ in
            openInBrowser(AppConfig.webSite)
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceItem = navigationItem.leftBarButtonItem
        present(sheet, animated: true)
    }

    private func actionAddOptions(from rect: CGRect) {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Add from Music Library", style: .default) { [weak self] _ in
            self?.showMediaPicker()
        })
        sheet.addAction(UIAlertAction(title: "Add from Video Library", style: .default) { [weak self] _ in
            self?.addVideoAction()
        })
        sheet.addAction(UIAlertAction(title: "Add by Pasting", style: .default) { [weak self] _ in
            self?.pasteAction()
        })
        sheet.addAction(UIAlertAction(title: "Add from Site", style: .default) { _ in
            openInBrowser(AppConfig.webSite)
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = tableView
            popover.sourceRect = rect
        }
        present(sheet, animated: true)
    }

    /// Create a song from the text on the pasteboard.
    private func pasteAction() {
        let song = songList.importSong(from: UIPasteboard.general.string ?? "", into: nil)
        Alerts.show("Pasted \(song.clipCount) clips for \(song.label ?? "")", title: "Paste")
        songList.selectSong(song)
        tableView.reloadData()
    }

    private func addVideoAction() {
        let browser = VideoBrowserController(title: "Select New Video") { [weak self] item in
            guard let self else { return }
            songList.addSong(for: item)
            navigationController?.popViewController(animated: true)
            selectCreatedSong()
        }
        navigationController?.pushViewController(browser, animated: true)
    }

    private func showMediaPicker() {
        songList.pause()
        let picker = MPMediaPickerController(mediaTypes: .any)
        picker.delegate = self
        picker.allowsPickingMultipleItems = false
        picker.prompt = "Add songs to play"
        present(picker, animated: true)
    }

    /// Select the song just added at the end of the list.
    private func selectCreatedSong() {
        let index = songList.songCount - 1
        guard index >= 0 else { return }
        songList.selectSong(songList.song(at: index))
        tableView.reloadData()
        let indexPath = IndexPath(row: index, section: 0)
        tableView.selectRow(at: indexPath, animated: true, scrollPosition: .middle)
        selectIndexPath = indexPath
    }

    // MARK: Table view

    /// Every row but the last is a song.
    private func isSongRow(_ row: Int) -> Bool {
        row < songList.songCount
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        songList.songCount + 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard isSongRow(indexPath.row) else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SongAddCell")
                ?? UITableViewCell(style: .default, reuseIdentifier: "SongAddCell")
            var content = cell.defaultContentConfiguration()
            content.text = "Add from iPod Library..."
            content.textProperties.color = .songClipsGreen
            cell.contentConfiguration = content
            cell.accessoryType = .disclosureIndicator
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: SongCell.reuseIdentifier) as? SongCell ?? SongCell()
        let song = songList.song(at: indexPath.row)
        cell.fTitle.text = song.label
        cell.fTitle.textColor = .black
        cell.fDetail.text = "\(song.albumTitle ?? "") - \(song.artist ?? "")"
        cell.accessoryType = isEditing ? .none : .disclosureIndicator
        cell.fImage.image = song.imageIcon
        return cell
    }

    override func tableView(
        _ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath
    ) -> UITableViewCell.EditingStyle {
        guard isEditing else { return .none }
        return isSongRow(indexPath.row) ? .delete : .insert
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard isSongRow(indexPath.row) else {
            actionAddOptions(from: tableView.rectForRow(at: indexPath))
            return
        }
        selectIndexPath = indexPath
        let wasPlaying = songList.isPlaying
        songList.selectSong(songList.song(at: indexPath.row))
        if wasPlaying {
            songList.play()
        }
        if !tableView.isEditing {
            navigationController?.pushViewController(AppDelegate.shared.fetchClipPlayView(), animated: true)
        }
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        isSongRow(indexPath.row)
    }

    override func tableView(
        _ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath
    ) {
        if isSongRow(sourceIndexPath.row) && isSongRow(destinationIndexPath.row) {
            songList.moveSong(from: sourceIndexPath.row, to: destinationIndexPath.row)
        }
        tableView.reloadData()
    }

    override func tableView(
        _ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath
    ) {
        guard editingStyle == .delete else { return }
        songList.removeSong(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .fade)
    }
}

extension SongListCtl: MPMediaPickerControllerDelegate {
    func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
        mediaPicker.dismiss(animated: true)
        songList.addSongs(from: mediaItemCollection)
        selectCreatedSong()
    }

    func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
        mediaPicker.dismiss(animated: true)
    }
}
