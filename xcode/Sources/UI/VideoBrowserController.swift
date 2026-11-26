//
//  VideoBrowserController.swift
//  SongClips
//
//  Lists the videos in the Music library with thumbnails (replaces Apple's AssetBrowser sample).
//

import AVFoundation
import MediaPlayer
import UIKit

final class VideoBrowserController: UITableViewController {
    private let onChoose: (MPMediaItem) -> Void
    private var items: [MPMediaItem] = []
    private var thumbnails: [MPMediaEntityPersistentID: UIImage] = [:]
    private var thumbnailRequests: Set<MPMediaEntityPersistentID> = []

    private static let rowHeight: CGFloat = 65
    private static let placeholder = UIImage(systemName: "film")

    init(title: String, onChoose: @escaping (MPMediaItem) -> Void) {
        self.onChoose = onChoose
        super.init(style: .plain)
        self.title = title
    }

    required init?(coder: NSCoder) {
        fatalError("VideoBrowserController is created in code")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = Self.rowHeight
        loadItems()
        NotificationCenter.default.addObserver(
            self, selector: #selector(libraryDidChange), name: .MPMediaLibraryDidChange, object: nil)
        MPMediaLibrary.default().beginGeneratingLibraryChangeNotifications()
    }

    @objc private func libraryDidChange() {
        loadItems()
    }

    private func loadItems() {
        let query = MPMediaQuery()
        query.addFilterPredicate(
            MPMediaPropertyPredicate(
                value: NSNumber(value: MPMediaType.anyVideo.rawValue), forProperty: MPMediaItemPropertyMediaType))
        items = (query.items ?? []).filter { $0.assetURL != nil && !$0.mediaType.intersection(.anyVideo).isEmpty }
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        items.isEmpty ? nil : "iPod Library"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")
            ?? UITableViewCell(style: .default, reuseIdentifier: "Cell")
        let item = items[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = item.title ?? item.assetURL?.lastPathComponent
        content.textProperties.font = .boldSystemFont(ofSize: 14)
        content.image = thumbnails[item.persistentID] ?? Self.placeholder
        content.imageProperties.maximumSize = CGSize(width: (Self.rowHeight - 1) * 1.5, height: Self.rowHeight - 1)
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        requestThumbnail(for: item)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onChoose(items[indexPath.row])
    }

    private func requestThumbnail(for item: MPMediaItem) {
        let id = item.persistentID
        guard thumbnails[id] == nil, !thumbnailRequests.contains(id), let url = item.assetURL else { return }
        thumbnailRequests.insert(id)
        let scale = traitCollection.displayScale
        let height = (Self.rowHeight - 1) * scale
        Task {
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: height * 1.5, height: height)
            guard let (cgImage, _) = try? await generator.image(at: CMTime(seconds: 1, preferredTimescale: 600)) else {
                return
            }
            thumbnails[id] = UIImage(cgImage: cgImage, scale: scale, orientation: .up)
            if let row = items.firstIndex(where: { $0.persistentID == id }) {
                tableView.reloadRows(at: [IndexPath(row: row, section: 0)], with: .none)
            }
        }
    }
}
