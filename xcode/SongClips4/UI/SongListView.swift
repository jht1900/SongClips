//
//  SongListView.swift
//  SongClips4
//
//  Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
//
//  The list of songs, with a last row for adding more.
//

import MediaPlayer
import SwiftUI

struct SongListView: View {
    private let songList = SongList.shared
    private let navigator = Navigator.shared

    @State private var editMode: EditMode = .inactive
    @State private var showOptions = false
    @State private var showAddOptions = false
    @State private var showMediaPicker = false

    private var isEditing: Bool { editMode.isEditing }

    var body: some View {
        List {
            ForEach(Array(songList.songs.enumerated()), id: \.element.id) { index, song in
                Button {
                    select(song)
                } label: {
                    SongRow(song: song, showsDisclosure: !isEditing)
                }
                .foregroundStyle(.primary)
                .listRowBackground(index == songList.currentSongIndex ? Color(.systemGray4) : nil)
            }
            .onDelete { offsets in
                for index in offsets.sorted(by: >) {
                    songList.removeSong(at: index)
                }
            }
            .onMove { source, destination in
                songList.moveSongs(fromOffsets: source, toOffset: destination)
            }

            Button {
                showAddOptions = true
            } label: {
                HStack {
                    Text("Add from iPod Library...")
                        .foregroundStyle(Color.songClipsGreen)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(minHeight: 44)
            .confirmationDialog("Add", isPresented: $showAddOptions, titleVisibility: .hidden) {
                Button("Add from Music Library") { showMediaPicker = true }
                Button("Add from Video Library") { navigator.push(.videoBrowser(.addSong)) }
                Button("Add by Pasting") { pasteAction() }
                Button("Add from Site") { openInBrowser(AppConfig.webSite) }
                Button("Cancel", role: .cancel) {}
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, $editMode)
        .navigationTitle(AppInfo.nameVersion)
        .navigationBarTitleDisplayMode(.inline)
        .songClipsNavigationBar()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showOptions = true
                } label: {
                    bundleImage("icon_48.png")
                        .resizable()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .confirmationDialog("Options", isPresented: $showOptions, titleVisibility: .hidden) {
                    Button("SongClips Website") { openInBrowser(AppConfig.webSite) }
                    Button("Cancel", role: .cancel) {}
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
                    .environment(\.editMode, $editMode)
            }
        }
        .sheet(isPresented: $showMediaPicker) {
            MediaPicker(prompt: "Add songs to play") { collection in
                songList.addSongs(from: collection)
                selectCreatedSong()
            }
            .ignoresSafeArea()
        }
    }

    /// Make `song` current, keep playing if we were, and show the player.
    private func select(_ song: Song) {
        let wasPlaying = songList.isPlaying
        songList.selectSong(song)
        if wasPlaying {
            songList.play()
        }
        if !isEditing {
            navigator.showPlayer()
        }
    }

    /// Create a song from the text on the pasteboard.
    private func pasteAction() {
        let song = songList.importSong(from: UIPasteboard.general.string ?? "", into: nil)
        Alerts.show("Pasted \(song.clipCount) clips for \(song.label ?? "")", title: "Paste")
        songList.selectSong(song)
    }

    /// Select the song just added at the end of the list.
    private func selectCreatedSong() {
        guard let song = songList.songs.last else { return }
        songList.selectSong(song)
    }
}

private struct SongRow: View {
    let song: Song
    let showsDisclosure: Bool

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let icon = song.imageIcon {
                    Image(uiImage: icon).resizable()
                } else {
                    Color.clear
                }
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(song.label ?? "")
                    .font(.headline)
                    .lineLimit(1)
                Text("\(song.albumTitle ?? "") - \(song.artist ?? "")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(minHeight: 54)
        .contentShape(Rectangle())
    }
}
