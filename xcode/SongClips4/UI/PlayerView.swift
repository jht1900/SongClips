//
//  PlayerView.swift
//  SongClips4
//
//  Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
//
//  The player: shows the current clip's notes and image while the song plays.
//  Edit mode adds clip splitting, merging, notes editing and photos.
//

import MediaPlayer
import PhotosUI
import SwiftUI

struct PlayerView: View {
    private let songList = SongList.shared
    private let navigator = Navigator.shared
    private let importer = SongImporter.shared

    @State private var editMode = false
    @State private var uiHidden = false

    @State private var scrubbing = false
    @State private var scrubValue = 0.0

    /// Notes being edited, and the clip they belong to.
    @State private var notesDraft = ""
    @State private var draftClip: Clip?
    @State private var notesDirty = false
    @FocusState private var notesFocused: Bool

    @State private var showPlayMode = false
    @State private var showMissing = false
    @State private var selectReplacementPending = false
    @State private var showReplacementPicker = false
    @State private var showCamera = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showImportPrompt = false

    private var song: Song? { songList.currentSong }
    private var clipIndex: Int { songList.reportedClipIndex }
    private var clip: Clip? { song?.clip(at: clipIndex) }
    private var clipStart: TimeInterval { clip?.startTime ?? 0 }
    private var clipDuration: TimeInterval { clip?.subDuration ?? 0 }
    private var songDuration: TimeInterval { song?.duration ?? 0 }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            if editMode {
                editBackground
            } else {
                playBackground
            }

            VStack(spacing: 0) {
                if editMode {
                    editPanels
                }
                Spacer(minLength: 0)
                if !uiHidden {
                    controlsBar
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(notesFocused)
        .toolbar(uiHidden ? .hidden : .visible, for: .navigationBar)
        .statusBarHidden(uiHidden)
        .songClipsNavigationBar()
        .toolbar {
            ToolbarItem(placement: .principal) {
                TitleView(top: titleTop, bottom: titleBottom)
            }
            ToolbarItem(placement: .topBarTrailing) {
                if notesFocused {
                    Button("Done") { finishNotesEditing() }
                } else {
                    Button("Clips") {
                        saveNotes()
                        navigator.push(.clips)
                    }
                }
            }
        }
        .onAppear(perform: appeared)
        .onChange(of: clip?.id, initial: true) { loadDraft() }
        .onChange(of: notesFocused) { _, focused in
            if focused { notesDirty = true }
        }
        .task(id: AutoPlayKey(playing: songList.playing, songID: song?.id)) {
            await autoPlay()
        }
        .fullScreenCover(isPresented: $showMissing, onDismiss: missingDismissed) {
            if let song {
                MissingMediaView(song: song) { selectReplacementPending = true }
            }
        }
        .sheet(isPresented: $showReplacementPicker) {
            MediaPicker(prompt: "Select Replacement") { collection in
                if let item = collection.items.first {
                    songList.replaceCurrentSongMedia(item)
                }
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showCamera) {
            let target = clip
            CameraPicker { image in target?.saveNewImage(image) }
                .ignoresSafeArea()
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            loadPhoto(item, into: clip)
        }
        .alert("Import SongClips", isPresented: $showImportPrompt) {
            Button("Cancel", role: .cancel) {}
            Button("Import") {
                if let song, let ref = song.clipsSourceRef {
                    importer.access(ref, into: song)
                }
            }
        } message: {
            Text(song?.clipsSourceRef ?? "")
        }
    }

    // MARK: Title

    private var titleTop: String {
        if importer.downloadStatus != nil { return importer.downloadTitle }
        return song?.label ?? ""
    }

    private var titleBottom: String {
        if let status = importer.downloadStatus { return status }
        guard let song else { return "" }
        if editMode {
            return "Editing Clip \(clipIndex + 1) of \(song.clipCount)"
        }
        return "\(song.artist ?? "") - \(song.albumTitle ?? "")"
    }

    // MARK: Play mode layout

    /// The clip's image (or the album art) behind its notes. A tap shows or hides the controls.
    private var playBackground: some View {
        ZStack(alignment: .top) {
            backImageView(backImage)
                .animation(.easeInOut(duration: 1), value: backImage.map(ObjectIdentifier.init))

            if songList.useAVPlayer {
                VideoLayerView()
            }

            if !uiHidden {
                ScrollView {
                    Text(clip?.notation ?? "")
                        .font(.custom("Helvetica-Bold", size: 19))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.top, 22)
                        .padding(.bottom, 140)
                }
                .scrollIndicators(.hidden)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: clickImageAction)
    }

    private var backImage: UIImage? {
        guard let song else { return UIImage(named: "Default.png") }
        return clip?.image ?? song.albumArt ?? UIImage(named: "no_artwork.png")
    }

    @ViewBuilder
    private func backImageView(_ image: UIImage?) -> some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .opacity(0.4)
                    .id(ObjectIdentifier(image))
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var controlsBar: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                Button { showPlayMode = true } label: {}
                    .buttonStyle(ImageButtonStyle(normal: "loop.png", pressed: "loop_hi.png"))
                    .popover(isPresented: $showPlayMode) {
                        PlayModeView { showPlayMode = false }
                            .presentationCompactAdaptation(.popover)
                    }
                Button(action: previousClipAction) {}
                    .buttonStyle(ImageButtonStyle(normal: "prev.png", pressed: "prev_hi.png"))
                Button { songList.togglePlayPause() } label: {}
                    .buttonStyle(
                        ImageButtonStyle(normal: songList.playing ? "paus.png" : "play.png", pressed: "play_hi.png"))
                Button(action: nextClipAction) {}
                    .buttonStyle(ImageButtonStyle(normal: "next.png", pressed: "next_hi.png"))
                Button(action: toggleEditMode) {}
                    .buttonStyle(ImageButtonStyle(normal: "clip.png", pressed: "clip_hi.png"))
            }

            Slider(value: scrubBinding, in: 0...1) { editing in
                scrubEditingChanged(editing)
            }
            .tint(.white)
            .padding(.horizontal, 12)

            HStack {
                Text(clipNumberText)
                Spacer()
                Text(runningTimeText)
                Spacer()
                Text(durationText)
            }
            .font(.custom("Helvetica-Bold", size: 12))
            .foregroundStyle(.white)
            .padding(.horizontal, 13)
            .padding(.bottom, 4)
        }
        .padding(.top, 2)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .background(Color.controlBar.opacity(0.7))
    }

    private var clipNumberText: String {
        guard let song else { return "" }
        return "Clip \(clipIndex + 1) of \(song.clipCount)"
    }

    private var runningTimeText: String {
        guard song != nil else { return "" }
        if editMode {
            return Format.runningTime(clipDuration * scrubPosition)
        }
        return Format.runningTime(songList.reportedTime)
    }

    private var durationText: String {
        guard song != nil else { return "" }
        return editMode ? "Clip \(Format.duration(clipDuration))" : "Song \(Format.duration(songDuration))"
    }

    // MARK: Edit mode layout

    private var editBackground: some View {
        ZStack {
            if songList.useAVPlayer {
                VideoLayerView()
            }
            if let image = clip?.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .opacity(0.4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var editPanels: some View {
        VStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                bundleImage("txt_add_text.png")
                    .resizable()
                    .frame(width: 80, height: 20)
                TextEditor(text: $notesDraft)
                    .font(.custom("Helvetica-Bold", size: 17))
                    .foregroundStyle(.black)
                    .scrollContentBackground(.hidden)
                    .background(.white)
                    .frame(height: 81)
                    .focused($notesFocused)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color.controlBar.opacity(0.7))

            if !songList.isVideo {
                HStack(spacing: 0) {
                    bundleImage("txt_add_img.png").resizable().frame(width: 64, height: 50)
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        bundleImage("lib.png").resizable().frame(width: 128, height: 50)
                    }
                    if CameraPicker.isAvailable {
                        Button { showCamera = true } label: {}
                            .buttonStyle(ImageButtonStyle(normal: "cam.png", pressed: "cam_hi.png"))
                            .frame(width: 128)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: 320)
                .frame(maxWidth: .infinity)
                .background(Color.controlBar.opacity(0.7))
            }

            HStack(spacing: 0) {
                bundleImage("txt_edit.png").resizable().frame(width: 64, height: 50)
                Button(action: splitAction) {}
                    .buttonStyle(ImageButtonStyle(normal: "split.png", pressed: "split_hi.png", height: 74))
                    .frame(width: 128)
                Button(action: mergeAction) {}
                    .buttonStyle(ImageButtonStyle(normal: "merge.png", pressed: "merge_hi.png", height: 74))
                    .frame(width: 128)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: 320)
            .frame(maxWidth: .infinity)
            .background(Color.controlBar.opacity(0.7))
        }
    }

    // MARK: Scrubber

    /// Position of the play head, 0...1, within the song, or within the clip when editing.
    private var scrubPosition: Double {
        if scrubbing { return scrubValue }
        let time = songList.reportedTime
        let position: Double
        if editMode {
            position = clipDuration > 0 ? (time - clipStart) / clipDuration : 0
        } else {
            position = songDuration > 0 ? time / songDuration : 0
        }
        return min(max(position, 0), 1)
    }

    private var scrubBinding: Binding<Double> {
        Binding(get: { scrubPosition }, set: { scrubValue = $0 })
    }

    private func scrubEditingChanged(_ editing: Bool) {
        if editing {
            scrubValue = scrubPosition
            scrubbing = true
            songList.isTracking = true
            return
        }
        let target = editMode ? clipStart + clipDuration * scrubValue : songDuration * scrubValue
        songList.currentTime = target
        songList.isTracking = false
        scrubbing = false
    }

    // MARK: Actions

    private func previousClipAction() {
        saveNotes()
        songList.previousClip()
    }

    private func nextClipAction() {
        saveNotes()
        songList.nextClip()
    }

    private func toggleEditMode() {
        saveNotes()
        notesFocused = false
        editMode.toggle()
        loadDraft()
    }

    /// Show or hide the controls, and open the clip's links.
    private func clickImageAction() {
        uiHidden.toggle()
        guard let clip else { return }
        if let linkRef = clip.linkRef, let url = SiteClient.url(from: linkRef) {
            navigator.push(.web(url))
        }
        if let webRef = clip.webRef {
            openInBrowser(webRef)
        }
    }

    /// Merge the current clip into the one before it.
    private func mergeAction() {
        saveNotes()
        guard let song else { return }
        let index = clipIndex
        song.removeClip(at: index)
        jumpToClip(at: max(index - 1, 0))
    }

    /// Split the current clip at the play position.
    private func splitAction() {
        saveNotes()
        guard let song else { return }
        let index = clipIndex
        song.splitClip(at: index, newSubDuration: songList.currentTime - clipStart)
        jumpToClip(at: min(index + 1, song.clipCount - 1))
    }

    private func jumpToClip(at index: Int) {
        let start = song?.clip(at: index)?.startTime ?? 0
        songList.setClipStartTime(start)
        songList.currentTime = start
    }

    // MARK: Notes

    /// Show the current clip's notes in the editor, saving unsaved edits to the previous clip first.
    private func loadDraft() {
        if notesDirty, let draftClip, draftClip !== clip {
            save(notesDraft, to: draftClip)
        }
        draftClip = clip
        notesDraft = clip?.notation ?? ""
        notesDirty = notesFocused
    }

    private func saveNotes() {
        guard notesDirty, let draftClip else { return }
        save(notesDraft, to: draftClip)
        notesDirty = notesFocused
    }

    private func save(_ text: String, to clip: Clip) {
        clip.notation = text
        guard let song = clip.song else { return }
        song.currentPos = songList.currentTime
        song.saveToDisk()
    }

    private func finishNotesEditing() {
        notesFocused = false
        notesDirty = true
        saveNotes()
        notesDirty = false
    }

    // MARK: Photos

    private func loadPhoto(_ item: PhotosPickerItem, into target: Clip?) {
        Task {
            defer { photoItem = nil }
            guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                Alerts.showError("Could not load the photo.")
                return
            }
            target?.saveNewImage(image)
        }
    }

    // MARK: Appearing

    private func appeared() {
        if navigator.checkMissingMediaPending {
            navigator.checkMissingMediaPending = false
            if checkSongMissingMedia() { return }
        }
        // A placeholder song: offer to import its clips.
        if let song, song.title == nil, song.clipsSourceRef != nil {
            showImportPrompt = true
        }
    }

    /// Explain when the current song's media is not in the Music library. Returns true if shown.
    private func checkSongMissingMedia() -> Bool {
        guard let song else { return false }
        song.queryForMediaItem()
        guard song.mediaMissing, song.sourceRef != nil, !song.mediaMissingShown else { return false }
        song.mediaMissingShown = true
        showMissing = true
        return true
    }

    private func missingDismissed() {
        guard selectReplacementPending else { return }
        selectReplacementPending = false
        if songList.isVideo {
            navigator.push(.videoBrowser(.replaceCurrentSong))
        } else {
            showReplacementPicker = true
        }
    }

    // MARK: Auto play

    private struct AutoPlayKey: Hashable {
        let playing: Bool
        let songID: UUID?
    }

    /// The first time the player shows a paused song, start playing after a second and hide the controls.
    private func autoPlay() async {
        guard !navigator.autoPlayDone, let song, !song.pauseOnLoad, !songList.playing else { return }
        try? await Task.sleep(for: .seconds(1))
        guard !Task.isCancelled, !navigator.autoPlayDone, !songList.isPlaying, !editMode else { return }
        navigator.autoPlayDone = true
        uiHidden = true
        songList.play()
    }
}
