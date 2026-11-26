//
//  ClipListCtl.swift
//  SongClips
//
//  The clips of a song. The playing clip is highlighted; tapping a clip plays it.
//

import UIKit

final class ClipListCtl: UITableViewController {
    private static let updateInterval: TimeInterval = 1.0

    private let song: Song
    private let songList = SongList.shared
    private var titleView: TitleView?
    private var lastTime: TimeInterval = 0
    private var currentClipIndex = 0

    init(song: Song) {
        self.song = song
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) {
        fatalError("ClipListCtl is created in code")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = 70
        tableView.allowsSelectionDuringEditing = true

        let titleView = TitleView(width: UIDevice.isPad ? 700 : 300)
        navigationItem.titleView = titleView
        self.titleView = titleView

        let infoButton = UIButton(type: .infoLight)
        infoButton.addTarget(self, action: #selector(infoAction), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: infoButton)
    }

    @objc private func infoAction() {
        let controller = InfoViewCtl()
        controller.title = AppInfo.nameVersion
        navigationController?.pushViewController(controller, animated: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
        songList.delegate = self

        currentClipIndex = song.clipIndex(for: songList.currentTime)
        if currentClipIndex < song.clipCount {
            tableView.scrollToRow(at: IndexPath(row: currentClipIndex, section: 0), at: .middle, animated: animated)
        }
        titleView?.fTop.text = song.label
        titleView?.fBottom.text = "\(song.clipCount) Clips"
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if AppDelegate.shared.mainViewController?.selectReplacementForCurrentSongPending == true {
            navigationController?.popViewController(animated: true)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        songList.delegate = nil
    }

    // MARK: Table view

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        song.clipCount
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ClipCell.reuseIdentifier) as? ClipCell ?? ClipCell()
        let row = indexPath.row
        guard let clip = song.clip(at: row) else { return cell }

        if let notation = clip.notation, !notation.isEmpty {
            cell.fNotes.text = notation
            cell.fNotes.textColor = .black
        } else {
            cell.fNotes.text = "Clip \(row + 1) of \(song.clipCount)"
            cell.fNotes.textColor = .gray
        }
        cell.fStartTime.text = ""
        cell.fDuration.text = Format.duration(clip.subDuration)

        if row == currentClipIndex {
            cell.fView.backgroundColor = .lightGray
            cell.fCurPos.text = Format.duration(songList.currentTime - clip.startTime)
        } else {
            cell.fView.backgroundColor = .white
            cell.fCurPos.text = ""
        }
        cell.fImage.image = clip.imageIcon
        cell.accessoryType = .none
        return cell
    }

    override func tableView(
        _ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath
    ) -> UITableViewCell.EditingStyle {
        .none
    }

    /// Play the tapped clip, or pause if it is already playing, and go back to the player.
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = indexPath.row
        guard let clip = song.clip(at: row) else { return }

        songList.currentTime = clip.startTime
        songList.establishClipForCurrentTime()
        if row == currentClipIndex && songList.isPlaying {
            songList.pause()
        } else {
            songList.play()
        }
        navigationController?.popViewController(animated: true)
    }
}

extension ClipListCtl: SongListWatcher {
    func reportSongChange() {
        lastTime = Date.timeIntervalSinceReferenceDate
        tableView.reloadData()
    }

    var isTracking: Bool { false }

    func timeReport(_ newTime: TimeInterval) {
        let index = song.clipIndex(for: newTime)
        let now = Date.timeIntervalSinceReferenceDate
        if index != currentClipIndex {
            currentClipIndex = index
            tableView.reloadData()
            lastTime = now
            return
        }
        if now - lastTime > Self.updateInterval {
            lastTime = now
            tableView.reloadData()
        }
    }
}
