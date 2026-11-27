//
//  SongClipsApp.swift
//  SongClips4
//
//  Copyright (C) 2009-2026 John Henry Thompson.
//
//  SwiftUI entry point (formerly AppDelegate, SceneDelegate and FirstStopViewCtl).
//

import MediaPlayer
import SwiftUI

@main
struct SongClipsApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        SongList.shared.resumeFromDisk()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { Navigator.shared.handleOpenURL($0) }
                .task { await requestMusicLibraryAccess() }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            let songList = SongList.shared
            if newPhase == .active {
                songList.becomeActive()
            } else if oldPhase == .active {
                songList.willResignActive()
            }
            if newPhase == .background {
                songList.currentSong?.mediaMissingShown = false
            }
        }
    }

    /// Ask for Music library access on first launch, then find the songs' media.
    private func requestMusicLibraryAccess() async {
        guard MPMediaLibrary.authorizationStatus() == .notDetermined else { return }
        let status = await withCheckedContinuation { continuation in
            MPMediaLibrary.requestAuthorization { @Sendable status in
                continuation.resume(returning: status)
            }
        }
        if status == .authorized {
            SongList.shared.refreshMediaItems()
        }
    }
}

/// The navigation stack, rooted at the song list.
struct RootView: View {
    @Bindable private var navigator = Navigator.shared
    private let alerts = Alerts.shared

    var body: some View {
        NavigationStack(path: $navigator.path) {
            SongListView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .player:
                        PlayerView()
                    case .clips:
                        ClipListView()
                    case .info:
                        InfoView()
                    case .web(let url):
                        WebPageView(url: url)
                    case .videoBrowser(let purpose):
                        VideoBrowserView(purpose: purpose)
                    }
                }
        }
        .alert(
            alerts.current?.title ?? "",
            isPresented: Binding(
                get: { alerts.current != nil },
                set: { if !$0 { alerts.current = nil } }),
            presenting: alerts.current
        ) { _ in
            Button("OK") {}
        } message: { alert in
            if let message = alert.message { Text(message) }
        }
    }
}
