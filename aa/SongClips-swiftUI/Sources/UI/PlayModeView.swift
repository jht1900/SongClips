//
//  PlayModeView.swift
//  SongClips4
//
//  Choose what happens at the end of each clip.
//

import SwiftUI

struct PlayModeView: View {
    private static let modes: [ClipPlayMode] = [.continue, .repeat, .pause, .pauseThenContinue, .pauseThenRepeat]

    let onDone: () -> Void
    private let songList = SongList.shared

    var body: some View {
        List {
            Section("At end of clip:") {
                ForEach(Self.modes, id: \.self) { mode in
                    Button {
                        choose(mode)
                    } label: {
                        HStack {
                            Text(mode.title)
                                .foregroundStyle(.primary)
                            Spacer()
                            if songList.playMode == mode {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .frame(minWidth: 300, minHeight: 300)
    }

    private func choose(_ mode: ClipPlayMode) {
        songList.setPlayMode(mode)
        // Leave the checkmark visible briefly before closing.
        Task {
            try? await Task.sleep(for: .seconds(0.25))
            onDone()
        }
    }
}
