//
//  AppConfig.swift
//  SongClips4
//
//  Copyright (C) 2009-2026 John Henry Thompson.
//

import Foundation
import os

/// App-wide constants (formerly AppDefs.h).
enum AppConfig {
    static let webSite = "http://www.j4u2.com/songclips"
    static let appStoreRef = "http://itunes.apple.com/us/app/songclips/id335528135?mt=8"

    /// Credentials for the SongClips download site.
    static let siteUsername = "art"
    static let sitePassword = "media201610"
    static let siteRealm = "dice"

    /// URL schemes this app is opened with.
    static let urlSchemePrefixes = ["songclips://", "songclips:"]

    static let exporterName = "SongClipper"

    /// Prefix for media files downloaded into a song folder.
    static let songMediaFilePrefix = "media-"

    static let maxImageSize = CGSize(width: 400, height: 400)
    static let imageIconSize = CGSize(width: 32, height: 32)

    static let maxCacheImages = 5
    static let maxCacheImageIcons = 100
}

/// Keys stored in `UserDefaults`.
enum DefaultsKey {
    static let playerTypePreference = "player_type_preference"
    static let songCurrentIndex = "kSongCurrentIndexKey"
    static let songCurrentTime = "kSongCurrentTimeKey"
    static let songPlayMode = "kSongPlayModeKey"
}

/// On-disk file names. These must not change: existing user data depends on them.
enum StoreFile {
    static let appPlist = "app.plist"
    static let songPlist = "song.plist"
}

let appLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SongClips", category: "app")
