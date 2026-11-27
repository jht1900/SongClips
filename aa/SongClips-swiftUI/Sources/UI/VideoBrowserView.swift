//
//  VideoBrowserView.swift
//  SongClips4
//
//  Lists the videos in the Music library with thumbnails, to add a song or replace the current song's media.
//

import AVFoundation
import MediaPlayer
import SwiftUI

struct VideoBrowserView: View {
    let purpose: VideoBrowserPurpose

    private static let rowHeight: CGFloat = 65

    @State private var items: [MPMediaItem] = []
    @State private var thumbnails: [MPMediaEntityPersistentID: UIImage] = [:]
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        List {
            if !items.isEmpty {
                Section("Music Library") {
                    ForEach(items, id: \.persistentID) { item in
                        Button {
                            choose(item)
                        } label: {
                            row(item)
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
        }
        .overlay {
            if items.isEmpty {
                ContentUnavailableView("No Videos", systemImage: "film", description: Text("No videos in the Music library."))
            }
        }
        .listStyle(.plain)
        .navigationTitle(purpose == .addSong ? "Select New Video" : "Select Replacement Video")
        .navigationBarTitleDisplayMode(.inline)
        .songClipsNavigationBar()
        .onAppear(perform: loadItems)
        .onReceive(NotificationCenter.default.publisher(for: .MPMediaLibraryDidChange)) { _ in
            loadItems()
        }
    }

    private func row(_ item: MPMediaItem) -> some View {
        HStack(spacing: 10) {
            Group {
                if let thumbnail = thumbnails[item.persistentID] {
                    Image(uiImage: thumbnail).resizable().scaledToFit()
                } else {
                    Image(systemName: "film")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: (Self.rowHeight - 1) * 1.5, height: Self.rowHeight - 1)

            Text(item.title ?? item.assetURL?.lastPathComponent ?? "")
                .font(.system(size: 14, weight: .bold))
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .task(id: item.persistentID) { await loadThumbnail(for: item) }
    }

    private func loadItems() {
        MPMediaLibrary.default().beginGeneratingLibraryChangeNotifications()
        let query = MPMediaQuery()
        query.addFilterPredicate(
            MPMediaPropertyPredicate(
                value: NSNumber(value: MPMediaType.anyVideo.rawValue), forProperty: MPMediaItemPropertyMediaType))
        items = (query.items ?? []).filter { $0.assetURL != nil && !$0.mediaType.intersection(.anyVideo).isEmpty }
    }

    private func loadThumbnail(for item: MPMediaItem) async {
        let id = item.persistentID
        guard thumbnails[id] == nil, let url = item.assetURL else { return }
        let height = (Self.rowHeight - 1) * displayScale
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: height * 1.5, height: height)
        guard let (cgImage, _) = try? await generator.image(at: CMTime(seconds: 1, preferredTimescale: 600)) else {
            return
        }
        thumbnails[id] = UIImage(cgImage: cgImage, scale: displayScale, orientation: .up)
    }

    private func choose(_ item: MPMediaItem) {
        let songList = SongList.shared
        Navigator.shared.pop()
        switch purpose {
        case .addSong:
            songList.addSong(for: item)
            if let song = songList.songs.last {
                songList.selectSong(song)
            }
        case .replaceCurrentSong:
            songList.replaceCurrentSongMedia(item)
        }
    }
}
