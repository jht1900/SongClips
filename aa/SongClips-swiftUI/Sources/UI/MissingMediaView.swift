//
//  MissingMediaView.swift
//  SongClips4
//
//  2011-11-21 jht
//
//  Shown when an imported song's media is not in the Music library.
//

import SwiftUI

struct MissingMediaView: View {
    let song: Song
    /// Called when the user wants to pick other media; the player shows the picker after this closes.
    let onSelectOther: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text("Song Missing")
                .font(.largeTitle.bold())

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Song:").bold()
                    Text(song.title ?? "")
                }
                GridRow {
                    Text("Album:").bold()
                    Text(song.albumTitle ?? "")
                }
                GridRow {
                    Text("Artist:").bold()
                    Text(song.artist ?? "")
                }
            }

            Text("not found in your music library.")
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Button("Select Alternative From Library") {
                    onSelectOther()
                    dismiss()
                }
                Button("Search in iTunes") {
                    let sourceRef = song.sourceRef
                    dismiss()
                    openInBrowser(sourceRef)
                }
                Button("Continue") {
                    dismiss()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
