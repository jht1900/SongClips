//
//  Storage.swift
//  SongClips4
//
//  File locations and property-list helpers (formerly UtilPath).
//

import Foundation

enum Storage {
    /// Root folder for all songs: `Library/Private Documents/`.
    /// Earlier versions stored data here, so the location must stay the same.
    static let rootURL: URL = {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return library.appendingPathComponent("Private Documents", isDirectory: true)
    }()

    /// Root folder path with a trailing slash. Song `partialPath` values are appended to it.
    static var rootPath: String { rootURL.path + "/" }

    static func readPlist(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
    }

    static func writePlist(_ dict: [String: Any], to url: URL) {
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
            try data.write(to: url, options: .atomic)
        } catch {
            appLog.error("writePlist failed \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    static func createDirectory(_ url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
