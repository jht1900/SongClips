//
//  InfoView.swift
//  SongClips4
//
//  Details for the current song, plus copy, email and website actions.
//

import SwiftUI

struct InfoView: View {
    private let songList = SongList.shared
    private let navigator = Navigator.shared

    @State private var showReplacementPicker = false
    @State private var showMail = false

    var body: some View {
        let song = songList.currentSong
        List {
            Section("Clips For: \(song?.label ?? "")") {
                Button(action: selectReplacementForCurrentSong) {
                    InfoRow(
                        title: song?.title ?? "No Media",
                        detail: song == nil ? nil : (songList.isVideo ? "Title (video)" : "Title (music)"),
                        titleColor: song == nil ? .primary : .songClipsGreen,
                        disclosure: true)
                }
                InfoRow(title: song?.albumTitle, detail: song == nil ? nil : "Album")
                InfoRow(title: song?.artist, detail: song == nil ? nil : "Artist")
                Button(action: downloadForCurrentSong) {
                    InfoRow(
                        title: song?.sourceForLocal,
                        detail: song?.sourceStream == true ? "Stream" : nil,
                        disclosure: true)
                }
                InfoRow(title: song?.partialPath, detail: song?.fileDisplaySize)
            }

            Section {
                Button(action: copyAction) {
                    InfoRow(title: "Copy", disclosure: true)
                }
                Button(action: emailAction) {
                    InfoRow(title: "Email", disclosure: true)
                }
            }

            Section {
                Button {
                    openInBrowser(AppConfig.webSite)
                } label: {
                    InfoRow(title: "SongClips Website", disclosure: true)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Info")
        .navigationBarTitleDisplayMode(.inline)
        .songClipsNavigationBar()
        .sheet(isPresented: $showReplacementPicker) {
            MediaPicker(prompt: "Select Replacement") { collection in
                if let item = collection.items.first {
                    songList.replaceCurrentSongMedia(item)
                }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showMail) {
            if let song {
                MailComposer(
                    subject: "\(AppInfo.name) for \(song.label ?? "") (\(song.clipCount) clips)",
                    body: song.exportString())
                .ignoresSafeArea()
            }
        }
    }

    // MARK: Actions

    /// Let the user pick different media for the current song.
    private func selectReplacementForCurrentSong() {
        guard songList.currentSong != nil else { return }
        if songList.isVideo {
            navigator.push(.videoBrowser(.replaceCurrentSong))
        } else {
            showReplacementPicker = true
        }
    }

    /// Download the current song's media again from its source.
    private func downloadForCurrentSong() {
        guard let song = songList.currentSong, song.sourceForLocal != nil else { return }
        song.sourceStream = false
        SongImporter.shared.downloadMedia(for: song)
    }

    /// Put the current song's clips on the pasteboard as text.
    private func copyAction() {
        guard let song = songList.currentSong else { return }
        UIPasteboard.general.string = song.exportString()
        Alerts.show("Copied \(song.clipCount) clips for \(song.title ?? "")", title: "Copy")
    }

    private func emailAction() {
        guard songList.currentSong != nil else { return }
        guard MailComposer.canSendMail else {
            Alerts.show("Set up a mail account to email clips.", title: "Email")
            return
        }
        showMail = true
    }
}

private struct InfoRow: View {
    let title: String?
    var detail: String?
    var titleColor: Color = .primary
    var disclosure = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title ?? "")
                    .foregroundStyle(titleColor)
                    .lineLimit(2)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if disclosure {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}
