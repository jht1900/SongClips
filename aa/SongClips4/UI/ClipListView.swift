//
//  ClipListView.swift
//  SongClips4
//
//  The clips of the current song. The playing clip is highlighted; tapping a clip plays it.
//

import SwiftUI

struct ClipListView: View {
    private let songList = SongList.shared
    private let navigator = Navigator.shared

    var body: some View {
        Group {
            if let song = songList.currentSong {
                clipList(song)
            } else {
                ContentUnavailableView("No Song", systemImage: "music.note")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .songClipsNavigationBar()
        .toolbar {
            ToolbarItem(placement: .principal) {
                TitleView(
                    top: songList.currentSong?.label ?? "",
                    bottom: "\(songList.currentSong?.clipCount ?? 0) Clips")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    navigator.push(.info)
                } label: {
                    Image(systemName: "info.circle")
                }
            }
        }
    }

    private func clipList(_ song: Song) -> some View {
        let currentIndex = songList.reportedClipIndex
        return ScrollViewReader { proxy in
            List {
                ForEach(Array(song.clips.enumerated()), id: \.element.id) { index, clip in
                    Button {
                        play(clip, at: index)
                    } label: {
                        ClipRow(clip: clip, index: index, clipCount: song.clipCount, isCurrent: index == currentIndex)
                    }
                    .listRowBackground(index == currentIndex ? Color(.lightGray) : Color.white)
                    .id(clip.id)
                }
            }
            .listStyle(.plain)
            .onAppear {
                if let clip = song.clip(at: currentIndex) {
                    proxy.scrollTo(clip.id, anchor: .center)
                }
            }
        }
    }

    /// Play the tapped clip, or pause if it is already playing, and go back to the player.
    private func play(_ clip: Clip, at index: Int) {
        let wasCurrent = index == songList.reportedClipIndex
        songList.currentTime = clip.startTime
        songList.establishClipForCurrentTime()
        if wasCurrent && songList.isPlaying {
            songList.pause()
        } else {
            songList.play()
        }
        navigator.pop()
    }
}

private struct ClipRow: View {
    let clip: Clip
    let index: Int
    let clipCount: Int
    let isCurrent: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Group {
                if let icon = clip.imageIcon {
                    Image(uiImage: icon).resizable()
                } else {
                    Color.clear
                }
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                if let notation = clip.notation, !notation.isEmpty {
                    Text(notation)
                        .foregroundStyle(.black)
                        .lineLimit(2)
                } else {
                    Text("Clip \(index + 1) of \(clipCount)")
                        .foregroundStyle(.gray)
                }
                HStack {
                    Text(Format.duration(clip.subDuration))
                    Spacer()
                    if isCurrent {
                        ClipPositionText(clip: clip)
                    }
                }
                .font(.caption)
                .foregroundStyle(.black.opacity(0.7))
            }
        }
        .frame(minHeight: 60)
        .contentShape(Rectangle())
    }
}

/// Time into the playing clip. A separate view so only it refreshes as time passes.
private struct ClipPositionText: View {
    let clip: Clip

    var body: some View {
        Text(Format.duration(max(SongList.shared.reportedTime - clip.startTime, 0)))
    }
}
