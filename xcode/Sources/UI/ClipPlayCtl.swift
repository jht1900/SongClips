//
//  ClipPlayCtl.swift
//  SongClips
//
//  Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
//
//  The player: shows the current clip's notes and image while the song plays.
//  Edit mode adds clip splitting, merging, notes editing and photos.
//

import MediaPlayer
import QuartzCore
import UIKit

final class ClipPlayCtl: UIViewController {
    /// How often the clip display refreshes while the clip is unchanged.
    private static let noteUpdateInterval: TimeInterval = 0.2
    /// Refresh interval right after a download, so its status stays readable.
    private static let noteUpdateIntervalHold: TimeInterval = 1.0

    @IBOutlet private var avplayer: PlaybackView!
    @IBOutlet private var fScrub: UISlider!
    @IBOutlet private var playPauseButton: UIButton!
    @IBOutlet private var loopClipButton: UIButton!
    @IBOutlet private var fclipnum: UILabel!
    @IBOutlet private var fduration: UILabel!
    @IBOutlet private var fduration2: UILabel!
    @IBOutlet private var backArtView: UIImageView!
    @IBOutlet private var notes: UITextView!
    @IBOutlet private var containerView: UIView!
    @IBOutlet private var controls: UIView!
    @IBOutlet private var fImageView: UIImageView!
    @IBOutlet private var fNotesContainer: UIView!
    @IBOutlet private var fNotes: UITextView!
    @IBOutlet private var fAddPhoto: UIView!
    @IBOutlet private var fEditBlock: UIView!
    @IBOutlet private var fCameraButton: UIButton!
    @IBOutlet private var fPhotoButton: UIButton!

    var selectReplacementForCurrentSongPending = false
    var checkSongMissingMediaPending = false

    private let songList = SongList.shared
    private var titleView: TitleView!
    private var customEditButton: UIBarButtonItem!
    private var albumArt: UIImage?

    private var lastSongFileName: String?
    /// Song to re-import clips into, after the user confirms the import.
    private var importSong: Song?
    private var importAlertShown = false
    private var accessActive = false

    private var lastClipIndex = -1
    private var lastTime: TimeInterval = 0
    private var lastClipStart: TimeInterval = 0
    private var lastClipDuration: TimeInterval = 0
    private var lastClipCount = 0
    private var lastSongDuration: TimeInterval = 0
    private var noteUpdateInterval = ClipPlayCtl.noteUpdateInterval

    private var scrubDownSeen = false
    private var playing = false
    private var editMode = false
    private var savePending = false
    private var uiHidden = false
    /// Playback has auto-started once since this screen was created.
    private var uiHiddenTriggered = false
    private var autoPlayScheduled = false
    private var downloadActive = false

    var currentSong: Song? { songList.currentSong }

    override var prefersStatusBarHidden: Bool { uiHidden }

    // MARK: View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        titleView = TitleView(width: UIDevice.isPad ? 688 : 240)
        navigationItem.titleView = titleView

        customEditButton = UIBarButtonItem(
            title: "Clips", style: .plain, target: self, action: #selector(showClipsListAction))
        navigationItem.rightBarButtonItem = customEditButton

        fScrub.addTarget(self, action: #selector(scrubTouchUpAction), for: .touchUpInside)
        fScrub.addTarget(self, action: #selector(scrubTouchDownAction), for: .touchDown)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        songList.setDelegate(self, view: avplayer)
        lastClipIndex = -1
        fNotes.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let app = AppDelegate.shared
        if let urlString = app.pendingAccessUrlStr {
            app.pendingAccessUrlStr = nil
            accessUrlStr(urlString)
            return
        }
        if selectReplacementForCurrentSongPending {
            selectReplacementForCurrentSongPending = false
            selectReplacementForCurrentSong()
            return
        }
        if checkSongMissingMediaPending {
            checkSongMissingMediaPending = false
            checkSongMissingMedia()
        }
        // A placeholder song: offer to import its clips.
        if let song = currentSong, song.title == nil, !importAlertShown {
            importAlertShown = true
            let alert = UIAlertController(title: "Import SongClips", message: song.clipsSourceRef, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
                self?.importAlertShown = false
            })
            alert.addAction(UIAlertAction(title: "Import", style: .default) { [weak self] _ in
                guard let self else { return }
                importAlertShown = false
                importSong = song
                if let ref = song.clipsSourceRef { accessUrlStr(ref) }
            })
            present(alert, animated: true)
            return
        }
        refreshView()
    }

    // MARK: Playback controls

    @IBAction private func playOrPauseMusic(_ sender: Any?) {
        playing = !songList.isPlaying
        reflectPlaying()
    }

    private func reflectPlaying() {
        if playing {
            songList.play()
        } else {
            songList.pause()
        }
        playPauseButton.isSelected = playing
    }

    @IBAction private func nextClipAction(_ sender: Any?) {
        saveActionPending()
        songList.nextClip()
    }

    @IBAction private func previousClipAction(_ sender: Any?) {
        saveActionPending()
        songList.previousClip()
    }

    /// Choose what happens at the end of each clip.
    @IBAction private func loopClipAction(_ sender: Any?) {
        let modeCtl = ClipPlayModeCtl()
        if UIDevice.isPad {
            let nav = UINavigationController(rootViewController: modeCtl)
            nav.modalPresentationStyle = .popover
            nav.popoverPresentationController?.sourceView = loopClipButton
            nav.popoverPresentationController?.sourceRect = loopClipButton.bounds
            modeCtl.onDone = { [weak nav] in nav?.dismiss(animated: true) }
            present(nav, animated: true)
        } else {
            navigationController?.pushViewController(modeCtl, animated: true)
        }
    }

    @objc private func showClipsListAction() {
        guard let song = currentSong else { return }
        navigationController?.pushViewController(ClipListCtl(song: song), animated: true)
    }

    /// A tap on the clip image shows or hides the controls, and opens the clip's links.
    func clickImageAction(_ sender: Any?) {
        uiHidden.toggle()
        reflectUIHidden()

        guard let song = currentSong, let clip = song.clip(at: song.clipIndex(for: songList.currentTime)) else {
            return
        }
        if let linkRef = clip.linkRef {
            WebViewController.show(urlString: linkRef, from: self)
        }
        if let webRef = clip.webRef {
            openInBrowser(webRef)
        }
    }

    private func reflectUIHidden() {
        navigationController?.setNavigationBarHidden(uiHidden, animated: false)
        setNeedsStatusBarAppearanceUpdate()
        controls.isHidden = uiHidden
        notes.isHidden = uiHidden
    }

    /// Start playing and hide the controls, once, when the screen first shows a song.
    private func playAndHideUI() {
        if !uiHidden {
            uiHidden = true
            reflectUIHidden()
        }
        playing = true
        reflectPlaying()
        uiHiddenTriggered = true
    }

    // MARK: Scrubber

    @objc private func scrubTouchDownAction() {
        scrubDownSeen = true
    }

    @objc private func scrubTouchUpAction() {
        // UIKit can send two touch-ups for one gesture; act on the first.
        guard scrubDownSeen else { return }
        scrubDownSeen = false
        let value = Double(fScrub.value)
        if editMode {
            songList.currentTime = lastClipStart + lastClipDuration * value
            updateCurPos()
        } else {
            songList.currentTime = lastSongDuration * value
        }
    }

    private func reportToScrub(_ time: TimeInterval) {
        // Leave the slider alone while the user drags it.
        guard !fScrub.isTracking else { return }
        if editMode {
            if lastClipDuration > 0 {
                fScrub.value = Float((time - lastClipStart) / lastClipDuration)
                updateCurPos()
            }
        } else {
            fScrub.value = lastSongDuration > 0 ? Float(time / lastSongDuration) : 0
        }
    }

    private func updateCurPos() {
        fduration.text = Format.runningTime(lastClipDuration * Double(fScrub.value))
    }

    // MARK: Display

    private func showTitle() {
        // Leave download progress on screen.
        guard !downloadActive else { return }
        let song = currentSong
        titleView.fTop.text = song?.label
        if editMode {
            titleView.fBottom.text = "Editing Clip \(songList.currentClipIndex + 1) of \(song?.clipCount ?? 0)"
        } else {
            titleView.fBottom.text = "\(song?.artist ?? "") - \(song?.albumTitle ?? "")"
        }
    }

    /// Show the clip at `lastClipIndex` in the editor, and optionally play from its start.
    private func showClip(jump: Bool = false) {
        guard let song = currentSong else { return }
        titleView.fBottom.text = "Editing Clip \(lastClipIndex + 1) of \(song.clipCount)"
        let clip = song.clip(at: lastClipIndex)
        lastClipStart = clip?.startTime ?? 0
        lastClipDuration = clip?.subDuration ?? 0
        fNotes.text = clip?.notation
        fclipnum.text = "Clip \(lastClipIndex + 1) of \(song.clipCount)"
        fduration2.text = "Clip \(Format.duration(lastClipDuration))"
        fImageView.image = clip?.image
        updateCurPos()

        songList.setClipStartTime(lastClipStart)
        if jump {
            songList.currentTime = lastClipStart
        }
    }

    private func updateForMediaItem(_ item: MPMediaItem?) {
        var backImage = UIImage(named: "no_artwork.png")
        if let artwork = item?.artwork, artwork.bounds.width > 0 {
            backImage = artwork.image(at: backArtView.frame.size)
        }
        newBackArt(backImage)
        albumArt = backImage
        showTitle()
    }

    private func newBackArt(_ image: UIImage?) {
        guard image !== backArtView.image else { return }
        performTransition()
        backArtView.image = image
    }

    /// Cross-fade the clip image area.
    private func performTransition() {
        let transition = CATransition()
        transition.duration = 1.0
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        transition.type = .fade
        containerView.layer.add(transition, forKey: nil)
    }

    private func noSong() {
        navigationItem.leftBarButtonItem = nil
        backArtView.image = UIImage(named: "Default.png")
        titleView.fTop.text = ""
        titleView.fBottom.text = ""
        notes.text = ""
        fScrub.value = 0
        fclipnum.text = ""
        fduration.text = ""
        fduration2.text = ""
    }

    /// Show or hide the editing controls to match `editMode`.
    private func refreshView() {
        lastSongDuration = currentSong?.duration ?? 0

        fImageView.isHidden = !editMode
        fNotesContainer.isHidden = !editMode
        fNotes.isHidden = !editMode
        fEditBlock.isHidden = !editMode
        containerView.isHidden = editMode
        notes.isHidden = editMode
        fAddPhoto.isHidden = true

        if editMode {
            showClip()
            if !songList.isVideo {
                let hasCamera = UIImagePickerController.isSourceTypeAvailable(.camera)
                let hasPhotoLibrary = UIImagePickerController.isSourceTypeAvailable(.photoLibrary)
                fCameraButton.isHidden = !hasCamera
                fPhotoButton.isHidden = !hasPhotoLibrary
                fAddPhoto.isHidden = !hasCamera && !hasPhotoLibrary
            }
        } else {
            reportSongChange()
            showTitle()
        }
    }

    // MARK: Editing

    @IBAction private func editClipAction(_ sender: Any?) {
        editMode.toggle()
        refreshView()
    }

    /// Merge the current clip into the one before it.
    @IBAction private func actionMerge(_ sender: Any?) {
        saveActionPending()
        currentSong?.removeClip(at: lastClipIndex)
        if lastClipIndex > 0 { lastClipIndex -= 1 }
        showClip(jump: true)
    }

    /// Split the current clip at the play position.
    @IBAction private func actionSplit(_ sender: Any?) {
        saveActionPending()
        guard let song = currentSong else { return }
        song.splitClip(at: lastClipIndex, newSubDuration: songList.currentTime - lastClipStart)
        if lastClipIndex < song.clipCount - 1 { lastClipIndex += 1 }
        showClip(jump: true)
    }

    private func saveActionPending() {
        if savePending { saveAction() }
    }

    @objc private func saveAction() {
        fNotes.resignFirstResponder()
        navigationItem.rightBarButtonItem = customEditButton
        saveClip()
    }

    private func saveClip() {
        guard let song = currentSong else { return }
        song.clip(at: lastClipIndex)?.notation = fNotes.text
        song.currentPos = songList.currentTime
        song.saveToDisk()
        savePending = false
    }

    // MARK: Photos

    @IBAction private func actionPhoto(_ sender: Any?) {
        pickImage(from: .photoLibrary, anchor: fPhotoButton)
    }

    @IBAction private func actionCamera(_ sender: Any?) {
        pickImage(from: .camera, anchor: fCameraButton)
    }

    private func pickImage(from source: UIImagePickerController.SourceType, anchor: UIView) {
        guard UIImagePickerController.isSourceTypeAvailable(source) else { return }
        let picker = UIImagePickerController()
        picker.sourceType = source
        picker.allowsEditing = true
        picker.delegate = self
        if UIDevice.isPad && source != .camera {
            picker.modalPresentationStyle = .popover
            picker.popoverPresentationController?.sourceView = anchor
            picker.popoverPresentationController?.sourceRect = anchor.bounds
        }
        present(picker, animated: true)
    }

    // MARK: Importing songs

    /// Import a song from a SongClips address (text export or JSON).
    func accessUrlStr(_ urlString: String) {
        guard !accessActive else { return }
        accessActive = true
        Task {
            defer { accessActive = false }
            do {
                let data = try await SiteClient.fetch(urlString)
                importSongData(data)
            } catch {
                appLog.error("Import failed \(urlString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func importSongData(_ data: Data) {
        let text = String(decoding: data, as: UTF8.self)
        let song = songList.importSong(from: text, into: importSong)
        importSong = nil

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

    /// Download the song's media from its `sourceForLocal` address.
    func downloadMedia(for song: Song) {
        selfOnTop()
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

        let downloader = FileDownloader(
            destination: destination,
            progress: { [weak self] bytes in
                guard let self else { return }
                downloadActive = true
                titleView.fTop.text = fileName
                titleView.fBottom.text = "Downloading \(Format.bytes(Double(bytes)))"
            },
            completion: { [weak self] error in
                self?.downloadFinished(error: error)
                self?.initNewSong(song)
            })
        downloader.start(from: url)
    }

    private func downloadFinished(error: Error?) {
        titleView.fBottom.text = error == nil ? "Download done" : "Download failed"
        noteUpdateInterval = Self.noteUpdateIntervalHold
        downloadActive = true
        Task {
            try? await Task.sleep(for: .seconds(Self.noteUpdateIntervalHold))
            downloadActive = false
            showTitle()
        }
    }

    private func initNewSong(_ song: Song) {
        song.initDeferred = false
        song.initForLocal()
        setupNewSong(song)
    }

    private func setupNewSong(_ song: Song) {
        songList.selectSong(song)
        // Rewind to the beginning of the song.
        songList.currentTime = 0
        lastTime = 0
        lastClipIndex = -1
        timeReport(0)
        selfOnTop()
    }

    private func selfOnTop() {
        guard let navigationController, navigationController.viewControllers.contains(self) else { return }
        navigationController.popToViewController(self, animated: false)
    }

    // MARK: Missing media

    /// Explain when the current song's media is not in the Music library. Returns true if shown.
    @discardableResult
    func checkSongMissingMedia() -> Bool {
        guard let song = currentSong else { return false }
        song.queryForMediaItem()
        guard song.mediaMissing, song.sourceRef != nil, !song.mediaMissingShown else { return false }
        song.mediaMissingShown = true
        let missing = MissingViewCtl(nibName: UIDevice.isPad ? "MissingViewCtl-iPad" : "MissingViewCtl", bundle: nil)
        // Full screen, so this screen's viewDidAppear runs when it closes.
        missing.modalPresentationStyle = .fullScreen
        present(missing, animated: true)
        return true
    }

    /// Let the user pick different media for the current song.
    func selectReplacementForCurrentSong() {
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
        guard let song = currentSong else { return }
        song.applyReplacement(item)
        song.saveToDisk()
        songList.selectSong(song)
        reportSongChange()
    }
}

// MARK: - SongListWatcher

extension ClipPlayCtl: SongListWatcher {
    func reportSongChange() {
        guard let song = currentSong else {
            noSong()
            return
        }
        updateForMediaItem(song.mediaItem)
        // Force an update.
        lastClipIndex = -1
        timeReport(songList.currentTime)
    }

    var isTracking: Bool { fScrub.isTracking }

    /// Called about ten times a second: update the scrubber, and the clip display when the clip changes.
    func timeReport(_ newTime: TimeInterval) {
        guard let song = currentSong else {
            noSong()
            return
        }
        lastSongDuration = song.duration
        reportToScrub(newTime)

        lastClipCount = song.clipCount
        let index = song.clipIndex(for: newTime)
        let clip = song.clip(at: index)
        let newNoteText = clip?.notation ?? ""
        var newClipImage = clip?.image
        if let clip {
            lastClipStart = clip.startTime
            lastClipDuration = clip.subDuration
        }
        songList.speedShiftMonitor(song)

        if lastSongFileName != song.storeName {
            // A different song: force a full update.
            lastClipIndex = -2
        }

        let now = Date.timeIntervalSinceReferenceDate
        let clipChanged = index != lastClipIndex
        guard clipChanged || now - lastTime >= noteUpdateInterval else { return }
        noteUpdateInterval = Self.noteUpdateInterval
        lastTime = now

        playPauseButton.isSelected = songList.isPlaying

        if clipChanged {
            lastSongFileName = song.storeName
            lastClipIndex = index
            songList.establishClip(at: index)
            if editMode {
                showClip()
            } else {
                notes.text = newNoteText
                if newClipImage == nil { newClipImage = albumArt }
                newBackArt(newClipImage)
                fclipnum.text = "Clip \(lastClipIndex + 1) of \(lastClipCount)"
                fduration2.text = "Song \(Format.duration(song.duration))"
            }
        }
        if editMode {
            updateCurPos()
        } else {
            fduration.text = Format.runningTime(songList.currentTime)
        }

        if !songList.isPlaying && !song.pauseOnLoad && !uiHiddenTriggered && !autoPlayScheduled {
            autoPlayScheduled = true
            Task {
                try? await Task.sleep(for: .seconds(1))
                autoPlayScheduled = false
                playAndHideUI()
            }
        }
    }
}

// MARK: - Text editing

extension ClipPlayCtl: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        // A Done button to dismiss the keyboard and save.
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(saveAction))
        savePending = true
    }
}

// MARK: - Pickers

extension ClipPlayCtl: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(
        _ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage,
            let song = currentSong
        {
            song.saveNewImage(image, forClipAt: lastClipIndex)
            fImageView.image = song.clip(at: lastClipIndex)?.image
        }
        picker.dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

extension ClipPlayCtl: MPMediaPickerControllerDelegate {
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
