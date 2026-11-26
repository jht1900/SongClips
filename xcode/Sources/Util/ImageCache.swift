//
//  ImageCache.swift
//  SongClips
//
//  Small least-recently-used cache for clip images (formerly Cache / CacheItem).
//

import UIKit

final class ImageCache {
    private struct Entry {
        let image: UIImage
        var stamp: Int
    }

    private var entries: [String: Entry] = [:]
    private var stamp = 0
    private let allowance: Int

    init(allowance: Int) {
        self.allowance = allowance
    }

    func add(_ image: UIImage, forKey key: String) {
        stamp += 1
        if entries[key] == nil, entries.count + 1 >= allowance {
            flushOldest()
        }
        entries[key] = Entry(image: image, stamp: stamp)
    }

    func image(forKey key: String) -> UIImage? {
        stamp += 1
        guard var entry = entries[key] else { return nil }
        entry.stamp = stamp
        entries[key] = entry
        return entry.image
    }

    func flush(forKey key: String) {
        entries[key] = nil
    }

    private func flushOldest() {
        if let oldest = entries.min(by: { $0.value.stamp < $1.value.stamp })?.key {
            entries[oldest] = nil
        }
    }
}
