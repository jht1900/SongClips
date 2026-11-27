//
//  Clip.swift
//  SongClips
//
//  Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
//
//  One section of a song: start time, duration, notes, and an optional image.
//

import UIKit

final class Clip {
    /// Keys in song.plist. These must not change: existing user data depends on them.
    private enum Key {
        static let texts = "texts"
        static let recordingFileName = "recordingFileName"
        static let recordingDuration = "recordingDuration"
        static let subDuration = "subDuration"
        static let imageFileName = "imageFileName"
        static let imageRef = "imageRef"
        static let linkRef = "linkRef"
        static let webRef = "webRef"
        static let clipRate = "K_clip_rate"
    }

    weak var song: Song?

    var texts: [String]?
    var recordingFileName: String?
    var imageFileName: String?
    /// Web address of the clip's image, downloaded on first use.
    var imageRef: String?
    /// Page shown inside the app when the clip image is tapped.
    var linkRef: String?
    /// Page opened in the browser when the clip image is tapped.
    var webRef: String?
    var recordingDuration: TimeInterval = 0
    var subDuration: TimeInterval = 0
    /// Playback rate for this clip; 0 means unchanged.
    var clipRate: Double = 0

    private var imageRequestActive = false
    private var imageRequestFailed = false

    init(song: Song?) {
        self.song = song
    }

    /// Start time, kept to 4 decimals to match the media player's resolution.
    var startTime: TimeInterval = 0 {
        didSet {
            let factor = 10000.0
            let truncated = (startTime * factor).rounded(.towardZero) / factor
            if truncated != startTime { startTime = truncated }
        }
    }

    /// All note texts joined by blank lines.
    var notation: String? {
        get {
            guard let texts, !texts.isEmpty else { return nil }
            return texts.joined(separator: "\n\n")
        }
        set {
            guard let newValue else { return }
            texts = [newValue]
        }
    }

    // MARK: Persistence

    var asDict: [String: Any] {
        var dict: [String: Any] = [
            Key.subDuration: subDuration,
            Key.recordingDuration: recordingDuration,
            Key.clipRate: clipRate,
        ]
        dict[Key.recordingFileName] = recordingFileName
        dict[Key.imageFileName] = imageFileName
        dict[Key.imageRef] = imageRef
        dict[Key.linkRef] = linkRef
        dict[Key.webRef] = webRef
        dict[Key.texts] = texts
        return dict
    }

    func load(from dict: [String: Any]) {
        subDuration = (dict[Key.subDuration] as? NSNumber)?.doubleValue ?? 0
        recordingFileName = dict[Key.recordingFileName] as? String
        recordingDuration = (dict[Key.recordingDuration] as? NSNumber)?.doubleValue ?? 0
        imageFileName = dict[Key.imageFileName] as? String
        imageRef = dict[Key.imageRef] as? String
        linkRef = dict[Key.linkRef] as? String
        webRef = dict[Key.webRef] as? String
        texts = dict[Key.texts] as? [String]
        clipRate = (dict[Key.clipRate] as? NSNumber)?.doubleValue ?? 0
    }

    // MARK: Images

    private var imagePath: String? {
        guard let imageFileName, let song else { return nil }
        return song.pathForMediaFile(imageFileName)
    }

    private var imageIconPath: String? {
        imagePath.map { $0 + "-icon" }
    }

    private var imageCacheKey: String? {
        imageRef ?? imagePath
    }

    private var imageIconCacheKey: String? {
        imageCacheKey.map { $0 + "-icon" }
    }

    /// The clip's image, loaded from disk or downloaded from `imageRef`.
    var image: UIImage? {
        loadImage(path: imagePath, cacheKey: imageCacheKey, cache: SongList.shared.imageCache)
    }

    /// 32x32 version of the clip's image.
    var imageIcon: UIImage? {
        loadImage(path: imageIconPath, cacheKey: imageIconCacheKey, cache: SongList.shared.imageIconCache)
    }

    private func loadImage(path: String?, cacheKey: String?, cache: ImageCache) -> UIImage? {
        if let cacheKey, let cached = cache.image(forKey: cacheKey) {
            return cached
        }
        guard let imageFileName, !imageFileName.isEmpty else {
            requestImageRef()
            return nil
        }
        guard let path, let cacheKey, let image = UIImage(contentsOfFile: path) else {
            appLog.error("Clip loadImage failed path=\(path ?? "nil", privacy: .public)")
            return nil
        }
        cache.add(image, forKey: cacheKey)
        return image
    }

    /// Save a new image for the clip, scaled to fit 400x400, plus its icon.
    func saveNewImage(_ newImage: UIImage) {
        var image = newImage
        let source = newImage.size
        let maxSize = AppConfig.maxImageSize
        if source.width > maxSize.width || source.height > maxSize.height {
            var target = maxSize
            if source.width > source.height, source.width != 0 {
                target.height = maxSize.height * (source.height / source.width)
            } else if source.height != 0 {
                target.width = maxSize.width * (source.width / source.height)
            }
            image = Self.scale(newImage, to: target)
        }

        if imageFileName?.isEmpty ?? true {
            imageFileName = song?.nextMediaFileName(suffix: "image.png")
        }
        guard let imagePath, let imageIconPath, let imageCacheKey, let imageIconCacheKey else { return }

        write(image, to: imagePath, cacheKey: imageCacheKey, cache: SongList.shared.imageCache)
        let icon = Self.scale(image, to: AppConfig.imageIconSize)
        write(icon, to: imageIconPath, cacheKey: imageIconCacheKey, cache: SongList.shared.imageIconCache)

        song?.saveToDisk()
    }

    private func write(_ image: UIImage, to path: String, cacheKey: String, cache: ImageCache) {
        if let data = image.pngData() {
            do {
                try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            } catch {
                appLog.error("Clip image write failed \(path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        } else {
            appLog.error("Clip pngData failed for \(path, privacy: .public)")
        }
        cache.add(image, forKey: cacheKey)
    }

    private static func scale(_ image: UIImage, to size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Delete the clip's image and recording files.
    func removeMediaFiles() {
        let fm = FileManager.default
        if let imagePath, let imageIconPath, !(imageFileName?.isEmpty ?? true) {
            try? fm.removeItem(atPath: imagePath)
            try? fm.removeItem(atPath: imageIconPath)
            if let imageCacheKey { SongList.shared.imageCache.flush(forKey: imageCacheKey) }
            if let imageIconCacheKey { SongList.shared.imageIconCache.flush(forKey: imageIconCacheKey) }
        }
        if let recordingFileName, !recordingFileName.isEmpty, let song {
            try? fm.removeItem(atPath: song.pathForMediaFile(recordingFileName))
        }
    }

    /// Download the image named by `imageRef`, once.
    private func requestImageRef() {
        guard let imageRef, !imageRequestActive, !imageRequestFailed else { return }
        imageRequestActive = true
        Task {
            defer { imageRequestActive = false }
            do {
                let data = try await SiteClient.fetch(imageRef)
                guard let image = UIImage(data: data) else {
                    imageRequestFailed = true
                    appLog.error("Clip image data not an image: \(imageRef, privacy: .public)")
                    return
                }
                saveNewImage(image)
                SongList.shared.reportSongChange()
            } catch {
                imageRequestFailed = true
                appLog.error("Clip image request failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
